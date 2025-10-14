package xyz.kaspernissen.todo_java;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.Instant;

public class TodoEvent {

    @JsonProperty("id")
    private Long id;

    @JsonProperty("name")
    private String name;

    @JsonProperty("timestamp")
    private String timestamp;

    public TodoEvent() {
    }

    public TodoEvent(Long id, String name) {
        this.id = id;
        this.name = name;
        this.timestamp = Instant.now().toString();
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(String timestamp) {
        this.timestamp = timestamp;
    }

    @Override
    public String toString() {
        return "TodoEvent{" +
                "id=" + id +
                ", name='" + name + '\'' +
                ", timestamp='" + timestamp + '\'' +
                '}';
    }
}
