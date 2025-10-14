package xyz.kaspernissen.todo_java;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

@Service
public class EventPublisher {

    private static final Logger logger = LoggerFactory.getLogger(EventPublisher.class);
    private final RabbitTemplate rabbitTemplate;

    public EventPublisher(RabbitTemplate rabbitTemplate) {
        this.rabbitTemplate = rabbitTemplate;
    }

    public void publishTodoCreated(Todo todo) {
        try {
            TodoEvent event = new TodoEvent(todo.getId(), todo.getName());

            logger.info("Publishing todo created event: id={}, name={}",
                event.getId(), event.getName());

            rabbitTemplate.convertAndSend(
                RabbitMQConfig.EXCHANGE_NAME,
                "todo.created",
                event
            );

            logger.info("Successfully published todo created event for id: {}", todo.getId());
        } catch (Exception e) {
            logger.error("Failed to publish todo created event for id: {}", todo.getId(), e);
            // Don't throw - we don't want to fail the API request if messaging fails
        }
    }

    public void publishTodoDeleted(Todo todo) {
        try {
            TodoEvent event = new TodoEvent(todo.getId(), todo.getName());

            logger.info("Publishing todo deleted event: id={}, name={}",
                event.getId(), event.getName());

            rabbitTemplate.convertAndSend(
                RabbitMQConfig.EXCHANGE_NAME,
                "todo.deleted",
                event
            );

            logger.info("Successfully published todo deleted event for id: {}", todo.getId());
        } catch (Exception e) {
            logger.error("Failed to publish todo deleted event for id: {}", todo.getId(), e);
            // Don't throw - we don't want to fail the API request if messaging fails
        }
    }
}
