import React, { useState, useEffect } from 'react';
import { reportError } from '@dash0/sdk-web';
import './App.css';

// The SDK's fetch instrumentation spans every request and propagates traceparent, so
// the happy path needs no instrumentation here.
//
// reportError is needed because these failures are *caught* -- the @dash0/error
// instrumentation only sees uncaught ones.

function App() {
  const [todos, setTodos] = useState([]);
  const [newTodo, setNewTodo] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [notifications, setNotifications] = useState([]);

  // Load todos and notifications on component mount
  useEffect(() => {
    loadTodos();
    loadNotifications();
    // Refresh notifications every 2 seconds
    const interval = setInterval(loadNotifications, 2000);
    return () => clearInterval(interval);
  }, []);

  const loadTodos = async () => {
    try {
      setIsLoading(true);
      const response = await fetch('/todos');

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      setTodos(data.content || []);
    } catch (err) {
      console.error('Error loading todos:', err);
      setError('Failed to load todos');
      reportError(err, { attributes: { 'user.action': 'load_todos' } });
    } finally {
      setIsLoading(false);
    }
  };

  const createTodo = async (e) => {
    e.preventDefault();

    try {
      setIsLoading(true);
      setError('');

      const response = await fetch('/todos', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ name: newTodo }),
      });

      if (response.ok) {
        const createdTodo = await response.json();
        setTodos(prev => [...prev, createdTodo]);
        setNewTodo('');
      } else {
        throw new Error('Failed to create todo - validation failed');
      }
    } catch (err) {
      console.error('Error creating todo:', err);
      setError(err.message);
      reportError(err, {
        attributes: { 'user.action': 'create_todo', 'todo.name': newTodo },
      });
    } finally {
      setIsLoading(false);
    }
  };

  const deleteTodo = async (id) => {
    try {
      setIsLoading(true);
      const response = await fetch(`/todos/${id}`, {
        method: 'DELETE',
      });

      if (response.ok) {
        setTodos(prev => prev.filter(todo => todo.id !== id));
      } else {
        throw new Error('Failed to delete todo');
      }
    } catch (err) {
      console.error('Error deleting todo:', err);
      setError('Failed to delete todo');
      reportError(err, {
        attributes: { 'user.action': 'delete_todo', 'todo.id': id },
      });
    } finally {
      setIsLoading(false);
    }
  };

  const loadNotifications = async () => {
    try {
      const response = await fetch('/notifications');
      if (response.ok) {
        const data = await response.json();
        setNotifications(data.slice(0, 10)); // Show only last 10
      }
    } catch (err) {
      console.error('Error loading notifications:', err);
    }
  };

  const clearNotifications = async () => {
    try {
      setIsLoading(true);
      const response = await fetch('/notifications', {
        method: 'DELETE',
      });

      if (response.ok) {
        setNotifications([]);
      } else {
        throw new Error('Failed to clear notifications');
      }
    } catch (err) {
      console.error('Error clearing notifications:', err);
      setError('Failed to clear notifications');
      reportError(err, {
        attributes: { 'user.action': 'clear_notifications' },
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>
          <img src="/opentelemetry-logo.svg" alt="OpenTelemetry" className="otel-logo" />
        </h1>
        <p>A simple todo app demonstrating distributed tracing</p>
      </header>

      <main className="App-main">
        {error && <div className="error">{error}</div>}
        
        <form onSubmit={createTodo} className="todo-form">
          <input
            type="text"
            value={newTodo}
            onChange={(e) => setNewTodo(e.target.value)}
            placeholder="Enter a new todo..."
            disabled={isLoading}
            required
          />
          <button type="submit" disabled={isLoading || !newTodo.trim()}>
            {isLoading ? 'Adding...' : 'Add Todo'}
          </button>
        </form>

        <div className="todos-container">
          <h2>Todos ({todos.length})</h2>
          {isLoading && <p>Loading...</p>}
          
          {todos.length === 0 && !isLoading ? (
            <p className="no-todos">No todos yet. Add one above!</p>
          ) : (
            <ul className="todos-list">
              {todos.map(todo => (
                <li key={todo.id} className="todo-item">
                  <span className="todo-name">{todo.name}</span>
                  <button 
                    onClick={() => deleteTodo(todo.id)}
                    className="delete-btn"
                    disabled={isLoading}
                  >
                    Delete
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        {notifications.length > 0 && (
          <div className="notifications-container">
            <h2>Recent Notifications ({notifications.length})</h2>
            <ul className="notifications-list">
              {notifications.map(notification => (
                <li key={notification.id} className={`notification-item ${notification.eventType}`}>
                  <div className="notification-content">
                    <span className="notification-icon">
                      {notification.eventType === 'created' ? '✓' : '✗'}
                    </span>
                    <span className="notification-todo">"{notification.todoName}"</span>
                    <span className="notification-time">
                      {new Date(notification.receivedAt).toLocaleTimeString()}
                    </span>
                  </div>
                </li>
              ))}
            </ul>
            <div className="clear-notifications-wrapper">
              <button
                onClick={clearNotifications}
                className="clear-notifications-btn"
                disabled={isLoading}
              >
                Clear Notifications
              </button>
            </div>
          </div>
        )}

      </main>

      <footer className="app-footer">
        <p>Crafted with ❤️ by <img src="/dash0-logo.svg" alt="Dash0" className="dash0-logo" /></p>
      </footer>
    </div>
  );
}

export default App;