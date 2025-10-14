import React, { useState, useEffect } from 'react';
import { trace, context } from '@opentelemetry/api';
import './App.css';

const tracer = trace.getTracer('frontend', '1.0.0');

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
    const span = tracer.startSpan('load_todos');
    span.setAttributes({
      'user.action': 'load_todos',
      'component': 'TodoList'
    });

    // Set the span as active so fetch instrumentation creates child spans
    return await context.with(trace.setSpan(context.active(), span), async () => {
      try {
        setIsLoading(true);
        const response = await fetch('/todos');

        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }

        const data = await response.json();
        setTodos(data.content || []);
        span.addEvent('Todos loaded successfully');
        span.setAttributes({
          'todos.count': data.content ? data.content.length : 0
        });
      } catch (err) {
        console.error('Error loading todos:', err);
        setError('Failed to load todos');
        span.recordException(err);
        span.setStatus({ code: 2, message: err.message });
      } finally {
        setIsLoading(false);
        span.end();
      }
    });
  };

  const createTodo = async (e) => {
    e.preventDefault();

    const span = tracer.startSpan('create_todo');
    span.setAttributes({
      'user.action': 'create_todo',
      'todo.name': newTodo,
      'todo.name.length': newTodo.length
    });

    // Set the span as active so fetch instrumentation creates child spans
    return await context.with(trace.setSpan(context.active(), span), async () => {
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
          span.addEvent('Todo created successfully');
          span.setAttributes({
            'todo.id': createdTodo.id,
            'operation.result': 'success'
          });
        } else {
          throw new Error('Failed to create todo - validation failed');
        }
      } catch (err) {
        console.error('Error creating todo:', err);
        setError(err.message);
        span.recordException(err);
        span.setStatus({ code: 2, message: err.message });
      } finally {
        setIsLoading(false);
        span.end();
      }
    });
  };

  const deleteTodo = async (id) => {
    const span = tracer.startSpan('delete_todo');
    span.setAttributes({
      'user.action': 'delete_todo',
      'todo.id': id
    });

    // Set the span as active so fetch instrumentation creates child spans
    return await context.with(trace.setSpan(context.active(), span), async () => {
      try {
        setIsLoading(true);
        const response = await fetch(`/todos/${id}`, {
          method: 'DELETE',
        });

        if (response.ok) {
          setTodos(prev => prev.filter(todo => todo.id !== id));
          span.addEvent('Todo deleted successfully');
          span.setAttributes({
            'operation.result': 'success'
          });
        } else {
          throw new Error('Failed to delete todo');
        }
      } catch (err) {
        console.error('Error deleting todo:', err);
        setError('Failed to delete todo');
        span.recordException(err);
        span.setStatus({ code: 2, message: err.message });
      } finally {
        setIsLoading(false);
        span.end();
      }
    });
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
    const span = tracer.startSpan('clear_notifications');
    span.setAttributes({
      'user.action': 'clear_notifications'
    });

    return await context.with(trace.setSpan(context.active(), span), async () => {
      try {
        setIsLoading(true);
        const response = await fetch('/notifications', {
          method: 'DELETE',
        });

        if (response.ok) {
          setNotifications([]);
          span.addEvent('Notifications cleared successfully');
          span.setAttributes({
            'operation.result': 'success'
          });
        } else {
          throw new Error('Failed to clear notifications');
        }
      } catch (err) {
        console.error('Error clearing notifications:', err);
        setError('Failed to clear notifications');
        span.recordException(err);
        span.setStatus({ code: 2, message: err.message });
      } finally {
        setIsLoading(false);
        span.end();
      }
    });
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