package model

type Task struct {
	ID          int64  `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Progress    int    `json:"progress"`
	Priority    int    `json:"priority"`
	Status      int    `json:"status"`
	DueAt       int64  `json:"due_at"`
	CreatedAt   int64  `json:"created_at"`
	UpdatedAt   int64  `json:"updated_at"`
	CompletedAt int64  `json:"completed_at,omitempty"`
}

const (
	TaskStatusActive    = 0
	TaskStatusDone      = 1
	TaskStatusAbandoned = 2
)

const (
	TaskPriorityNormal     = 0
	TaskPriorityImportant  = 1
	TaskPriorityUrgent     = 2
)

func ValidTaskPriority(p int) bool {
	return p == TaskPriorityNormal || p == TaskPriorityImportant || p == TaskPriorityUrgent
}

func ValidProgress(p int) bool {
	return p == 0 || p == 25 || p == 50 || p == 75 || p == 100
}