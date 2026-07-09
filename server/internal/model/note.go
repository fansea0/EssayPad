package model

type Note struct {
	ID        int64  `json:"id"`
	Category  int    `json:"category"`
	Title     string `json:"title"`
	Content   string `json:"content"`
	CreatedAt int64  `json:"created_at"`
	UpdatedAt int64  `json:"updated_at"`
	TaskID    int64  `json:"task_id"`
}