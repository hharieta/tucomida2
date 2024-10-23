```mermaid
---
title: tucomida2.0
---

erDiagram

users {
    INT IdUser PK
    VARCHAR Name
    BYTEA Password
    VARCHAR Email
    TIMESTAMP created_at
}

roles {
    INT IdRole
    VARCHAR Name
    TIMESTAMP created_at
}

user_roles {
    INT IdUserRole PK
    INT IdUser FK
    INT IdRole FK
    TIMESTAMP created_at
}
users ||--o{ user_roles : "assigned to"
roles ||--o{ user_roles : "grants"

address {
    INT IdAddress PK
    VARCHAR Street
    INT Number
    VARCHAR City
    VARCHAR State
    VARCHAR Country
    VARCHAR PostalCode
    VARCHAR UrlMaps
    TIMESTAMP created_at
}

restaurants {
    INT IdRestaurant PK
    INT IdAddress FK
    VARCHAR Name
    VARCHAR Phone
    VARCHAR UrlImage
    TIMESTAMP created_at
}
restaurants ||--|| address : "located at"

menus {
    INT IdMenu PK
    INT IdRestaurant FK
    VARCHAR Name
    TEXT Description
    DECIMAL Price
    VARCHAR UrlImage
    TIMESTAMP created_at
}
restaurants ||--o{ menus : "offers"

days {
    INT IdDay PK
    VARCHAR Name
    TIMESTAMP created_at
}

schedules {
    INT IdSchedule PK
    INT IdRestaurant FK
    INT IdDay FK
    TIME OpenTime
    TIME CloseTime
    TIMESTAMP created_at
}
restaurants ||--o{ schedules : "operates on"
days ||--o{ schedules: "have"

categories {
    INT IdCategory PK
    VARCHAR Name
    TIMESTAMP created_at
}

restaurant_categories {
    INT IdRestaurantCategory PK
    INT IdRestaurant FK
    INT IdCategory FK
    TIMESTAMP created_at
}
restaurants ||--o{ restaurant_categories : "belongs to"
categories ||--o{ restaurant_categories : "classified as"

review {
    INT IdReview PK
    INT IdUser FK
    INT IdRestaurant FK
    INT Rating
    TEXT Comment
    DATE DateReview
    TIMESTAMP created_at
}
users ||--o{ review : "writes"
restaurants ||--o{ review : "receives"


````
