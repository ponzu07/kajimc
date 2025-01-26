import express from 'express';
import { WebSocketServer } from 'ws';
import { createServer } from 'http';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { promises as fs } from 'fs';
import chokidar from 'chokidar';

const app = express();
const server = createServer(app);
const wss = new WebSocketServer({ server });

const __dirname = dirname(fileURLToPath(import.meta.url));
const LUA_DIR = '/lua/computer';
const LOG_DIR = '/app/logs';

const logger = {
  log: async (level, ...args) => {
    const timestamp = new Date().toISOString();
    const message = `[${timestamp}] ${level}: ${args.map(arg => 
      typeof arg === 'object' ? JSON.stringify(arg) : arg
    ).join(' ')}`;
    
    console[level === 'ERROR' ? 'error' : 'log'](message);
    
    try {
      await fs.appendFile(
        join(LOG_DIR, 'kajiedi.log'),
        message + '\n',
        'utf-8'
      );
    } catch (err) {
      console.error('Failed to write to log file:', err);
    }
  },
  debug: (...args) => logger.log('DEBUG', ...args),
  error: (...args) => logger.log('ERROR', ...args),
  info: (...args) => logger.log('INFO', ...args)
};

const readDirectoryRecursive = async (dirPath, parentPath = '') => {
  try {
    logger.debug(`Reading directory: ${dirPath} (parent: ${parentPath})`);
    const entries = await fs.readdir(dirPath, { withFileTypes: true });
    logger.debug(`Found ${entries.length} entries in ${dirPath}`);

    const contents = await Promise.all(
      entries.map(async (entry) => {
        try {
          const fullPath = join(dirPath, entry.name);
          const relativePath = join(parentPath, entry.name).replace(/\\/g, '/');
          const stats = await fs.stat(fullPath);
          const isDirectory = entry.isDirectory();

          logger.debug('Processing entry:', {
            name: entry.name,
            relativePath,
            isDirectory,
            fullPath,
            size: stats.size
          });

          const item = {
            name: entry.name,
            path: relativePath,
            isDirectory,
            size: stats.size,
            modifiedAt: stats.mtime
          };

          if (isDirectory) {
            const children = await readDirectoryRecursive(fullPath, relativePath);
            if (children.length > 0) {
              item.children = children;
              logger.debug(`Directory ${relativePath} has ${children.length} children`);
            }
          }

          return item;
        } catch (err) {
          logger.error(`Error processing entry ${entry.name}:`, err);
          return null;
        }
      })
    );

    return contents.filter(Boolean);
  } catch (error) {
    logger.error(`Error reading directory ${dirPath}:`, error);
    return [];
  }
};

app.use(express.json());

app.get('/api/files', async (req, res) => {
  try {
    logger.info('Reading files from:', LUA_DIR);
    
    // Get file tree data
    const contents = await readDirectoryRecursive(LUA_DIR);
    logger.debug('Raw directory contents:', JSON.stringify(contents, null, 2));

    // Create root computer node
    const root = {
      name: 'computer',
      path: 'computer',
      isDirectory: true,
      size: 0,
      modifiedAt: new Date(),
      children: contents
    };

    // Log complete tree for debugging
    const logTree = (node, depth = 0) => {
      const indent = '  '.repeat(depth);
      logger.debug(`${indent}${node.path} (${node.isDirectory ? 'dir' : 'file'})`);
      if (node.children) {
        node.children.forEach(child => logTree(child, depth + 1));
      }
    };

    logger.debug('Final tree structure:');
    logTree(root);
    
    res.json([root]);
  } catch (err) {
    logger.error('Error handling /api/files request:', err);
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/files/:path(*)', async (req, res) => {
  try {
    const filePath = join(LUA_DIR, req.params.path);
    logger.debug('Reading file:', filePath);
    const content = await fs.readFile(filePath, 'utf-8');
    res.json({ content });
  } catch (err) {
    logger.error('Error reading file:', err);
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/files/:path(*)', async (req, res) => {
  try {
    const filePath = join(LUA_DIR, req.params.path);
    logger.debug('Writing to file:', filePath);
    await fs.writeFile(filePath, req.body.content, 'utf-8');
    res.json({ success: true });
  } catch (err) {
    logger.error('Error writing file:', err);
    res.status(500).json({ error: err.message });
  }
});

const watcher = chokidar.watch(LUA_DIR, {
  ignored: /(^|[\/\\])\../,
  persistent: true
});

watcher.on('change', (path) => {
  const relativePath = path.substring(LUA_DIR.length + 1).replace(/\\/g, '/');
  logger.debug('File changed:', relativePath);
  broadcast(relativePath, {
    type: 'fileChanged',
    path: relativePath
  });
});

const activeSessions = new Map();
const fileClients = new Map();

const broadcast = (fileId, data, excludeClient = null) => {
  if (fileClients.has(fileId)) {
    for (const client of fileClients.get(fileId)) {
      if (client !== excludeClient && client.readyState === 1) {
        client.send(JSON.stringify(data));
      }
    }
  }
};

wss.on('connection', (ws) => {
  const sessionId = Math.random().toString(36).substr(2, 9);
  logger.info(`New WebSocket connection established: ${sessionId}`);
  activeSessions.set(ws, sessionId);

  ws.on('message', async (message) => {
    try {
      const data = JSON.parse(message);
      logger.debug('WebSocket message received:', { type: data.type, fileId: data.fileId });
      
      switch (data.type) {
        case 'open':
          if (!fileClients.has(data.fileId)) {
            fileClients.set(data.fileId, new Set());
          }
          fileClients.get(data.fileId).add(ws);
          break;

        case 'close':
          if (fileClients.has(data.fileId)) {
            fileClients.get(data.fileId).delete(ws);
          }
          break;

        case 'change':
          broadcast(data.fileId, data, ws);
          break;
      }
    } catch (err) {
      logger.error('WebSocket message error:', err);
    }
  });

  ws.on('close', () => {
    logger.info(`WebSocket connection closed: ${sessionId}`);
    activeSessions.delete(ws);
    for (const clients of fileClients.values()) {
      clients.delete(ws);
    }
  });
});

const port = process.env.PORT || 3000;
server.listen(port, () => {
  logger.info(`Server running on port ${port}`);
});

process.on('uncaughtException', (err) => {
  logger.error('Uncaught exception:', err);
});

process.on('unhandledRejection', (err) => {
  logger.error('Unhandled rejection:', err);
});
