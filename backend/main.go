package main

import (
	"github.com/gin-contrib/cors"
	"log"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

var db *gorm.DB

func main() {
	var err error
	db, err = gorm.Open(sqlite.Open("data.db"), &gorm.Config{})
	if err != nil {
		log.Fatal("failed to connect database:", err)
	}

	// Auto migrate models (creates tables)
	if err := db.AutoMigrate(&Collection{}, &Book{}); err != nil {
		log.Fatal("failed to migrate:", err)
	}

	r := gin.Default()

	r.Use(cors.New(cors.Config{
		AllowOrigins: []string{"http://localhost:8000"},
		AllowMethods: []string{"POST", "GET", "PATCH"},
		//AllowHeaders: []string{"Origin", "Content-Type"},
	}))

	// Routes
	r.GET("/collections", getCollections)
	r.POST("/collections", createCollection)
	r.GET("/collections/:collectionId/books", getBooksInCollection)
	r.POST("/collections/:collectionId/books", addBookToCollection)
	r.PATCH("/collections/:collectionId/books/:bookId/toggle", toggleBook)

	log.Println("Server started at :8080")
	err = r.Run(":8080")
	if err != nil {
		log.Fatal(err)
	}
}

// Handler: list all collections
func getCollections(c *gin.Context) {
	var collections []Collection
	if err := db.Preload("Books").Find(&collections).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch collections"})
		return
	}
	c.JSON(http.StatusOK, collections)
}

// Handler: create collection
func createCollection(c *gin.Context) {
	var input struct {
		Name string `json:"name" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name is required"})
		return
	}

	collection := Collection{Name: input.Name}
	if err := db.Create(&collection).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create collection"})
		return
	}
	c.JSON(http.StatusOK, collection)
}

// Handler: list books in a collection
func getBooksInCollection(c *gin.Context) {
	collectionId, err := strconv.Atoi(c.Param("collectionId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid collection id"})
		return
	}

	var books []Book
	if err := db.Where("collection_id = ?", collectionId).Order("position").Find(&books).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to fetch books"})
		return
	}
	c.JSON(http.StatusOK, books)
}

// Handler: add book to collection
func addBookToCollection(c *gin.Context) {
	collectionId, err := strconv.Atoi(c.Param("collectionId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid collection id"})
		return
	}

	var input struct {
		Name     string `json:"name" binding:"required"`
		Position int    `json:"position" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name and position are required"})
		return
	}

	task := Book{
		Name:         input.Name,
		Position:     input.Position,
		Done:         false,
		CollectionID: uint(collectionId),
	}

	if err := db.Create(&task).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create book"})
		return
	}
	c.JSON(http.StatusOK, task)
}

// Handler: toggle book done status
func toggleBook(c *gin.Context) {
	bookId, err := strconv.Atoi(c.Param("bookId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid book id"})
		return
	}

	var task Book
	if err := db.First(&task, bookId).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "book not found"})
		return
	}

	task.Done = !task.Done
	if err := db.Save(&task).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update"})
		return
	}

	c.JSON(http.StatusOK, task)
}
