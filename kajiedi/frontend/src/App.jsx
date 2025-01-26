import { useState } from 'react';
import Split from 'react-split';
import { FileTree } from './components/FileTree';
import { CodeEditor } from './components/Editor';
import './App.css';

export const App = () => {
  const [selectedFile, setSelectedFile] = useState(null);

  const handleFileSelect = (file) => {
    if (!file.isDirectory) {
      setSelectedFile(file);
    }
  };

  return (
    <div className="app">
      <header className="header">
        <h1>KajiEdi</h1>
      </header>
      <Split
        className="split-view"
        sizes={[20, 80]}
        minSize={100}
        gutterSize={4}
        snapOffset={30}
      >
        <div className="file-explorer">
          <FileTree
            onFileSelect={handleFileSelect}
            selectedPath={selectedFile?.path}
          />
        </div>
        <div className="editor-container">
          <CodeEditor file={selectedFile} />
        </div>
      </Split>
    </div>
  );
};
