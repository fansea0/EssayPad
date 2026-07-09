package model

type PomodoroSession struct {
	ID             int64  `json:"id"`
	TaskID         int64  `json:"task_id"`
	PlannedMinutes int    `json:"planned_minutes"`
	ActualMinutes  int    `json:"actual_minutes"`
	Status         int    `json:"status"`
	StartedAt      int64  `json:"started_at"`
	EndedAt        int64  `json:"ended_at"`
	Note           string `json:"note"`
}

const (
	PomodoroStatusRunning   = 0
	PomodoroStatusCompleted = 1
	PomodoroStatusAborted   = 2
)

const PomodoroMaxLimit = 99