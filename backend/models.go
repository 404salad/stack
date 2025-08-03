package main

import (
	_ "gorm.io/gorm"
)

type Collection struct {
	ID    uint   `gorm:"primaryKey" json:"id"`
	Name  string `json:"name"`
	Books []Book `json:"books"`
}

type Book struct {
	ID           uint   `gorm:"primaryKey" json:"book_id"`
	Name         string `json:"name"`
	Position     int    `json:"position"`
	Done         bool   `json:"done"`
	CollectionID uint   `json:"collection_id"`
}
