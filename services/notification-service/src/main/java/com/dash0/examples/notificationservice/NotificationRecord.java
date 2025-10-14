package com.dash0.examples.notificationservice;

public class NotificationRecord {
    private Long todoId;
    private String todoName;
    private String timestamp;
    private String receivedAt;

    public NotificationRecord(Long todoId, String todoName, String timestamp, String receivedAt) {
        this.todoId = todoId;
        this.todoName = todoName;
        this.timestamp = timestamp;
        this.receivedAt = receivedAt;
    }

    public Long getTodoId() {
        return todoId;
    }

    public void setTodoId(Long todoId) {
        this.todoId = todoId;
    }

    public String getTodoName() {
        return todoName;
    }

    public void setTodoName(String todoName) {
        this.todoName = todoName;
    }

    public String getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(String timestamp) {
        this.timestamp = timestamp;
    }

    public String getReceivedAt() {
        return receivedAt;
    }

    public void setReceivedAt(String receivedAt) {
        this.receivedAt = receivedAt;
    }
}
