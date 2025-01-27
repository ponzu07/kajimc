<?php
declare(strict_types=1);

// Configuration
ini_set('display_errors', '1');
ini_set('log_errors', '1');
ini_set('error_log', '/var/log/php/debug.log');
error_reporting(E_ALL);

const UPLOAD_DIR = __DIR__ . '/mod/';
const CONFIG_FILE = __DIR__ . '/config/admins.php';
const JSON_FILE = UPLOAD_DIR . 'mods.json';
const ZIP_FILE = UPLOAD_DIR . 'pack.zip';

$ADMIN_IPS = file_exists(CONFIG_FILE) ? require CONFIG_FILE : [];

class ModManager {
    private array $mods = [];
    private bool $isAdmin;
    
    public function __construct() {
        global $ADMIN_IPS;
        
        // CloudflareのCF-Connecting-IPヘッダーから実IPを取得
        $clientIp = $_SERVER['REMOTE_ADDR'] ?? '';  // nginx設定でCF-Connecting-IPがREMOTE_ADDRに設定される
        $source = 'CF-Connecting-IP via REMOTE_ADDR';
        
        // IPv6アドレスを正規化
        if (strpos($clientIp, ':') !== false) {
            $clientIp = inet_ntop(inet_pton($clientIp));
        }
        
        // デバッグ情報
        error_log(sprintf(
            "[DEBUG] Client IP Detection:\n".
            "Found IP: %s\n".
            "Source: %s\n".
            "Is IPv6: %s\n".
            "Client Info:\n".
            "Real IP: %s\n".
            "Country: %s\n".
            "Headers:\n".
            "REMOTE_ADDR: %s\n".
            "CF-Connecting-IP: %s\n".
            "X-Forwarded-For: %s\n".
            "\nRegistered Admin IPs:\n%s",
            $clientIp,
            $source,
            (strpos($clientIp, ':') !== false ? 'Yes' : 'No'),
            $clientIp,
            $_SERVER['HTTP_CF_IPCOUNTRY'] ?? 'unknown',
            $_SERVER['REMOTE_ADDR'] ?? 'not set',
            $_SERVER['HTTP_CF_CONNECTING_IP'] ?? 'not set',
            $_SERVER['HTTP_X_FORWARDED_FOR'] ?? 'not set',
            implode("\n", array_map(fn($ip) => "- $ip", $ADMIN_IPS))
        ));
        
        $this->isAdmin = in_array($clientIp, $ADMIN_IPS, true);
        error_log(sprintf(
            "[DEBUG] Admin Check:\n".
            "Result: %s\n".
            "Client IP: %s\n".
            "Matching: %s",
            $this->isAdmin ? 'Yes' : 'No',
            $clientIp,
            $this->isAdmin ? 'Found in admin list' : 'Not found in admin list'
        ));
        
        $this->loadMods();
    }
    
    private function loadMods(): void {
        if (file_exists(JSON_FILE)) {
            $data = json_decode(file_get_contents(JSON_FILE), true);
            $this->mods = $data['mods'] ?? [];
        }
    }
    
    private function saveMods(): void {
        file_put_contents(JSON_FILE, json_encode(['mods' => $this->mods], JSON_PRETTY_PRINT));
    }
    
    private function updateZipFile(): void {
        $zip = new ZipArchive();
        if ($zip->open(ZIP_FILE, ZipArchive::CREATE | ZipArchive::OVERWRITE)) {
            foreach ($this->mods as $mod) {
                $modPath = UPLOAD_DIR . $mod['filename'];
                if (file_exists($modPath)) {
                    $zip->addFile($modPath, $mod['filename']);
                }
            }
            $zip->close();
        }
    }
    
    public function uploadMod(string $name, array $file): string {
        if (!$this->isAdmin) {
            throw new RuntimeException('管理者権限がありません');
        }
        
        if ($file['error'] !== UPLOAD_ERR_OK) {
            throw new RuntimeException('ファイルアップロードエラー');
        }
        
        $filename = basename($file['name']);
        $uploadFile = UPLOAD_DIR . $filename;
        
        if (!move_uploaded_file($file['tmp_name'], $uploadFile)) {
            throw new RuntimeException('ファイルの移動に失敗しました');
        }
        
        $this->mods[] = ['name' => $name, 'filename' => $filename];
        $this->saveMods();
        $this->updateZipFile();
        
        return 'アップロードが完了しました';
    }
    
    public function deleteMod(int $index): void {
        if (!$this->isAdmin) {
            throw new RuntimeException('管理者権限がありません');
        }
        
        if (!isset($this->mods[$index])) {
            throw new RuntimeException('指定されたModが見つかりません');
        }
        
        $filename = $this->mods[$index]['filename'];
        $filepath = UPLOAD_DIR . $filename;
        
        if (file_exists($filepath)) {
            unlink($filepath);
        }
        
        array_splice($this->mods, $index, 1);
        $this->saveMods();
        $this->updateZipFile();
    }
    
    public function getMods(): array {
        return $this->mods;
    }
    
    public function isAdmin(): bool {
        return $this->isAdmin;
    }
}

$manager = new ModManager();
$message = $error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        if (isset($_POST['delete'])) {
            $manager->deleteMod((int)$_POST['delete']);
        } elseif (isset($_FILES['modFile'], $_POST['modName'])) {
            $message = $manager->uploadMod($_POST['modName'], $_FILES['modFile']);
        }
    } catch (RuntimeException $e) {
        $error = $e->getMessage();
    }
}
?>
<?php
$showAdmin = $manager->isAdmin();
?>
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>KajiMC - Mod配布ページ</title>
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@400;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/assets/css/style.css">
    <?php if (!$showAdmin): ?>
    <style>
    .admin-only { display: none !important; }
    </style>
    <?php endif; ?>
</head>
<body>
    <div class="container">
        <div class="server-info">
            <h1>KajiMC サーバー</h1>
            <div class="ip-box" onclick="copyIP()">
                <span id="server-ip">mc.copirobo.com</span>
                <svg class="copy-icon" viewBox="0 0 24 24" width="20" height="20" fill="#ffffff">
                    <path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/>
                </svg>
            </div>
        </div>

        <?php if ($showAdmin): ?>
        <div class="admin-panel">
            <h2>Mod管理パネル</h2>
            <?php if ($error): ?>
                <div class="error"><?= htmlspecialchars($error) ?></div>
            <?php endif; ?>
            <?php if ($message): ?>
                <div class="message"><?= htmlspecialchars($message) ?></div>
            <?php endif; ?>
            <form method="POST" enctype="multipart/form-data">
                <div class="form-group">
                    <label for="modName">Mod名:</label>
                    <input type="text" id="modName" name="modName" required>
                </div>
                <div class="form-group">
                    <label for="modFile">Modファイル（最大50MB）:</label>
                    <input type="file" id="modFile" name="modFile" accept=".jar" required>
                </div>
                <button type="submit" class="btn">アップロード</button>
            </form>
        </div>
        <?php endif; ?>

        <div class="download-section">
            <h2>必要なMod一覧</h2>
            <p>以下のModをすべてインストールしてください</p>
            <?php if (file_exists(ZIP_FILE)): ?>
            <a href="/mod/pack.zip" download class="btn">すべてのModをダウンロード</a>
            <?php endif; ?>
        </div>

        <div class="mod-list">
            <?php foreach ($manager->getMods() as $index => $mod): ?>
                <div class="mod-card">
                    <div class="mod-name"><?= htmlspecialchars($mod['name']) ?></div>
                    <a href="/mod/<?= htmlspecialchars($mod['filename']) ?>" download class="btn">ダウンロード</a>
                    <?php if ($showAdmin): ?>
                        <form method="POST" style="display: inline;">
                            <input type="hidden" name="delete" value="<?= $index ?>">
                            <button type="submit" class="delete-btn" onclick="return confirm('このModを削除してもよろしいですか？')">×</button>
                        </form>
                    <?php endif; ?>
                </div>
            <?php endforeach; ?>
        </div>
    </div>
    <script src="/assets/js/script.js"></script>
</body>
</html>
