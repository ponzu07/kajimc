import { useState, useEffect } from 'react';

const FileItem = ({ item, depth = 0, onSelect, selectedPath, expandedPaths, onToggle }) => {
  const isSelected = selectedPath === item.path;
  const isExpanded = item.isDirectory && expandedPaths.has(item.path);
  const isFile = !item.isDirectory;
  const hasChildren = item.children && item.children.length > 0;

  // Log for debugging
  console.log('Rendering item:', {
    name: item.name,
    path: item.path,
    type: isFile ? 'file' : 'directory',
    expanded: isExpanded,
    depth,
    children: hasChildren ? item.children.map(c => c.name) : []
  });

  const handleClick = () => {
    if (isFile) {
      console.log('Selected file:', item.path);
      onSelect(item);
    } else {
      handleToggle();
    }
  };

  const handleToggle = (e) => {
    if (e) {
      e.stopPropagation();
    }
    if (!isFile) {
      console.log('Toggle directory:', {
        path: item.path,
        wasExpanded: isExpanded,
        hasChildren
      });
      onToggle(item.path);
    }
  };

  return (
    <div 
      className="file-item-container"
      data-type={isFile ? 'file' : 'directory'}
      data-path={item.path}
      data-depth={depth}
    >
      <div 
        className={`file-item ${isSelected ? 'selected' : ''} ${isFile ? 'file-entry' : 'directory'}`}
        onClick={handleClick}
        data-depth={depth}
      >
        {!isFile && (
          <span 
            className="toggle" 
            onClick={handleToggle}
            role="button"
            tabIndex={0}
            aria-label={isExpanded ? 'Collapse' : 'Expand'}
          >
            {isExpanded ? '▼' : '▶'}
          </span>
        )}
        <span 
          className={`icon ${isFile ? 'file' : 'folder'}`} 
          role="img" 
          aria-label={isFile ? 'File' : 'Folder'}
        />
        <span className="file-name">{item.name}</span>
      </div>

      {hasChildren && (
        <div 
          className={`file-children ${isExpanded ? 'expanded' : ''}`}
          data-parent={item.path}
        >
          {isExpanded && item.children.map((child, index) => (
            <FileItem
              key={`${child.path}-${index}`}
              item={child}
              depth={depth + 1}
              onSelect={onSelect}
              selectedPath={selectedPath}
              expandedPaths={expandedPaths}
              onToggle={onToggle}
            />
          ))}
        </div>
      )}
    </div>
  );
};

export const FileTree = ({ onFileSelect, selectedPath }) => {
  const [files, setFiles] = useState([]);
  const [expandedPaths, setExpandedPaths] = useState(() => new Set(['computer']));
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const loadFiles = async () => {
      try {
        setLoading(true);
        setError(null);
        
        console.log('Fetching file tree...');
        const response = await fetch('/api/files');
        if (!response.ok) {
          throw new Error(`Failed to load files: ${response.statusText}`);
        }

        const data = await response.json();
        console.log('Received data:', data);

        if (!Array.isArray(data) || !data[0]) {
          throw new Error('Invalid response format');
        }

        const [root] = data;
        console.log('Root node:', {
          name: root.name,
          path: root.path,
          children: root.children?.map(c => ({
            name: c.name,
            path: c.path,
            isDirectory: c.isDirectory
          }))
        });

        if (!root.children || !Array.isArray(root.children)) {
          throw new Error('Invalid file tree structure');
        }

        setFiles([root]);

        // Expand all directories by default
        const paths = new Set(['computer']);
        const collectPaths = (node) => {
          console.log('Processing node:', node.path);
          if (node.isDirectory) {
            paths.add(node.path);
            console.log('Added directory to expanded paths:', node.path);
            if (node.children?.length > 0) {
              node.children.forEach(collectPaths);
            }
          }
        };

        if (root.children.length > 0) {
          root.children.forEach(collectPaths);
        }

        console.log('Expanded paths:', Array.from(paths));
        setExpandedPaths(paths);

      } catch (error) {
        console.error('Failed to load files:', error);
        setError(error.message);
      } finally {
        setLoading(false);
      }
    };

    loadFiles();
  }, []);

  const handleToggle = (path) => {
    console.log('Toggle path:', path);
    setExpandedPaths(prev => {
      const newPaths = new Set(prev);
      if (newPaths.has(path)) {
        newPaths.delete(path);
        console.log('Collapsed:', path);
      } else {
        newPaths.add(path);
        console.log('Expanded:', path);
      }
      return newPaths;
    });
  };

  if (loading) {
    return <div>Loading file structure...</div>;
  }

  if (error) {
    return <div className="error">{error}</div>;
  }

  if (!files.length) {
    return <div className="error">No files found</div>;
  }

  return (
    <div className="file-tree">
      {files.map((file, index) => (
        <FileItem
          key={`${file.path}-${index}`}
          item={file}
          depth={0}
          onSelect={onFileSelect}
          selectedPath={selectedPath}
          expandedPaths={expandedPaths}
          onToggle={handleToggle}
        />
      ))}
    </div>
  );
};
