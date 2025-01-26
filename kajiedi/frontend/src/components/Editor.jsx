import { useRef, useEffect, useState } from 'react';
import Editor from '@monaco-editor/react';

const AUTOSAVE_DELAY = 1000;

export const CodeEditor = ({ file }) => {
  const [content, setContent] = useState('');
  const editorRef = useRef(null);
  const wsRef = useRef(null);
  const saveTimeoutRef = useRef(null);
  const ignoreChangeRef = useRef(false);

  const setupWebSocket = () => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.close();
    }

    wsRef.current = new WebSocket(`ws://${window.location.host}/ws`);
    wsRef.current.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.type === 'change' && data.fileId === file.path) {
        ignoreChangeRef.current = true;
        editorRef.current?.setValue(data.content);
        ignoreChangeRef.current = false;
      }
    };

    wsRef.current.onopen = () => {
      wsRef.current.send(JSON.stringify({
        type: 'open',
        fileId: file.path
      }));
    };

    return () => {
      if (wsRef.current) {
        wsRef.current.send(JSON.stringify({
          type: 'close',
          fileId: file.path
        }));
        wsRef.current.close();
      }
    };
  };

  useEffect(() => {
    const loadContent = async () => {
      try {
        const response = await fetch(`/api/files/${encodeURIComponent(file.path)}`);
        const data = await response.json();
        setContent(data.content);
      } catch (error) {
        console.error('Failed to load file content:', error);
      }
    };

    if (file) {
      loadContent();
      return setupWebSocket();
    }
  }, [file]);

  const handleEditorDidMount = (editor) => {
    editorRef.current = editor;
  };

  const saveContent = async (content) => {
    try {
      await fetch(`/api/files/${encodeURIComponent(file.path)}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content })
      });
    } catch (error) {
      console.error('Failed to save file:', error);
    }
  };

  const handleChange = (value) => {
    if (ignoreChangeRef.current) return;

    setContent(value);
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify({
        type: 'change',
        fileId: file.path,
        content: value
      }));
    }

    if (saveTimeoutRef.current) {
      clearTimeout(saveTimeoutRef.current);
    }

    saveTimeoutRef.current = setTimeout(() => {
      saveContent(value);
    }, AUTOSAVE_DELAY);
  };

  if (!file) return null;

  return (
    <Editor
      height="100%"
      defaultLanguage="lua"
      value={content}
      onChange={handleChange}
      onMount={handleEditorDidMount}
      options={{
        minimap: { enabled: false },
        scrollBeyondLastLine: false,
        fontSize: 14,
        lineNumbers: 'on',
        renderWhitespace: 'selection',
        tabSize: 2,
        automaticLayout: true
      }}
      theme="vs-dark"
    />
  );
};
