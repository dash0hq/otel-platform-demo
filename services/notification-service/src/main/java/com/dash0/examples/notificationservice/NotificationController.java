package com.dash0.examples.notificationservice;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/notifications")
@CrossOrigin(origins = "*")
public class NotificationController {

    @Autowired
    private NotificationRepository notificationRepository;

    @GetMapping
    public List<Notification> getRecentNotifications() {
        return notificationRepository.findTop50ByOrderByReceivedAtDesc();
    }

    @GetMapping("/count")
    public long getNotificationCount() {
        return notificationRepository.count();
    }

    @DeleteMapping
    public void clearNotifications() {
        notificationRepository.deleteAll();
    }
}
