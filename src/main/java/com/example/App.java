package com.example;

public class App {
    public static void main(String[] args) throws InterruptedException {
        System.out.println("Hello from CI/CD Pipeline! App is running inside Docker container.");
        while (true) {
            Thread.sleep(60000); // keep the app running
        }
    }
}

