package com.dash0.examples.notificationservice;

import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.metrics.LongCounter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class NotificationConsumer {

    private static final Logger logger = LoggerFactory.getLogger(NotificationConsumer.class);

    @Autowired
    private NotificationRepository notificationRepository;

    private final LongCounter createdNotificationsCounter;
    private final LongCounter deletedNotificationsCounter;

    public NotificationConsumer() {
        var openTelemetry = GlobalOpenTelemetry.get();
        this.createdNotificationsCounter = openTelemetry.getMeter("notification-consumer")
            .counterBuilder("notifications.created")
            .setDescription("Number of created notifications sent")
            .build();
        this.deletedNotificationsCounter = openTelemetry.getMeter("notification-consumer")
            .counterBuilder("notifications.deleted")
            .setDescription("Number of deleted notifications sent")
            .build();
    }

    @RabbitListener(queues = RabbitMQConfig.CREATED_QUEUE_NAME)
    public void handleTodoCreatedEvent(TodoEvent todoEvent) {
        try {
            logger.info("Received todo created event: id={}, name={}, timestamp={}",
                todoEvent.getId(),
                todoEvent.getName(),
                todoEvent.getTimestamp());

            // Save notification to database
            Notification notification = new Notification(
                todoEvent.getId(),
                todoEvent.getName(),
                "created",
                todoEvent.getTimestamp()
            );
            notificationRepository.save(notification);
            logger.info("Saved created notification to database for todo id: {}", todoEvent.getId());

            // Simulate notification processing
            logger.info("Processing notification for todo: \"{}\" was successfully created",
                todoEvent.getName());

            // Here you would send actual notifications (email, SMS, push, etc.)
            createdNotificationsCounter.add(1);
            logger.info("Notification processed successfully for todo id: {}", todoEvent.getId());

        } catch (Exception e) {
            logger.error("Error processing todo created event: {}", e.getMessage(), e);
            throw e; // Rethrow to trigger requeue if needed
        }
    }

    @RabbitListener(queues = RabbitMQConfig.DELETED_QUEUE_NAME)
    public void handleTodoDeletedEvent(TodoEvent todoEvent) {
        try {
            logger.info("Received todo deleted event: id={}, name={}, timestamp={}",
                todoEvent.getId(),
                todoEvent.getName(),
                todoEvent.getTimestamp());

            // Save notification to database
            Notification notification = new Notification(
                todoEvent.getId(),
                todoEvent.getName(),
                "deleted",
                todoEvent.getTimestamp()
            );
            notificationRepository.save(notification);
            logger.info("Saved deleted notification to database for todo id: {}", todoEvent.getId());

            // Simulate notification processing
            logger.info("Processing notification for todo: \"{}\" was successfully deleted",
                todoEvent.getName());

            // Here you would send actual notifications (email, SMS, push, etc.)
            deletedNotificationsCounter.add(1);
            logger.info("Notification processed successfully for todo id: {}", todoEvent.getId());

        } catch (Exception e) {
            logger.error("Error processing todo deleted event: {}", e.getMessage(), e);
            throw e; // Rethrow to trigger requeue if needed
        }
    }
}
