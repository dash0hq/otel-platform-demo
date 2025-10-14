package com.dash0.examples.notificationservice;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;

@Entity
@Table(name = "notifications")
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "todo_id", nullable = false)
    private Long todoId;

    @Column(name = "todo_name", nullable = false)
    private String todoName;

    @Column(name = "event_type", nullable = false)
    private String eventType;

    @Column(name = "event_timestamp")
    private String eventTimestamp;

    @Column(name = "received_at", nullable = false)
    private LocalDateTime receivedAt;

    public Notification() {
    }

    public Notification(Long todoId, String todoName, String eventType, String eventTimestamp) {
        this.todoId = todoId;
        this.todoName = todoName;
        this.eventType = eventType;
        this.eventTimestamp = eventTimestamp;
        // Use Europe/Oslo timezone (Norway)
        this.receivedAt = ZonedDateTime.now(ZoneId.of("Europe/Oslo")).toLocalDateTime();
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
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

    public String getEventTimestamp() {
        return eventTimestamp;
    }

    public void setEventTimestamp(String eventTimestamp) {
        this.eventTimestamp = eventTimestamp;
    }

    public LocalDateTime getReceivedAt() {
        return receivedAt;
    }

    public void setReceivedAt(LocalDateTime receivedAt) {
        this.receivedAt = receivedAt;
    }

    public String getEventType() {
        return eventType;
    }

    public void setEventType(String eventType) {
        this.eventType = eventType;
    }
}
