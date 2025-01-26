function copyIP() {
    navigator.clipboard.writeText(document.getElementById('server-ip').textContent)
        .then(() => alert('サーバーIPをコピーしました！'));
}
