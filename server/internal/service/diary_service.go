package service

import (
	"errors"
	"strings"

	"essaypad/internal/model"
	"essaypad/internal/store"
)

var ErrInvalidDiaryDate = errors.New("invalid diary date")
var ErrInvalidDiaryMood = errors.New("invalid diary mood")
var ErrInvalidDiaryStatus = errors.New("invalid diary status")
var ErrInvalidDiaryActivity = errors.New("invalid diary activity")

type DiaryService struct {
	dao *store.DiaryDAO
}

func NewDiaryService(dao *store.DiaryDAO) *DiaryService {
	return &DiaryService{dao: dao}
}

func (s *DiaryService) CreateOrUpdateByDate(entry *model.DiaryEntry) (*model.DiaryEntry, error) {
	if err := validateDiary(entry); err != nil {
		return nil, err
	}
	normalizeDiary(entry)
	return s.dao.CreateOrUpdateByDate(entry)
}

func (s *DiaryService) Get(id int64) (*model.DiaryEntry, error) {
	return s.dao.Get(id)
}

func (s *DiaryService) GetByDate(userID, diaryDate int64) (*model.DiaryEntry, error) {
	if diaryDate <= 0 {
		return nil, ErrInvalidDiaryDate
	}
	return s.dao.GetByDate(userID, diaryDate)
}

func (s *DiaryService) List(filter store.DiaryListFilter) ([]*model.DiaryEntry, int, error) {
	return s.dao.List(filter)
}

func (s *DiaryService) Update(id int64, fields map[string]interface{}) (*model.DiaryEntry, error) {
	if v, ok := fields["title"].(string); ok {
		fields["title"] = strings.TrimSpace(v)
	}
	if v, ok := fields["mood"].(int); ok && !model.ValidDiaryMood(v) {
		return nil, ErrInvalidDiaryMood
	}
	if v, ok := fields["status"].(int); ok && !model.ValidDiaryStatus(v) {
		return nil, ErrInvalidDiaryStatus
	}
	if v, ok := fields["activity"].(int); ok && !model.ValidDiaryActivity(v) {
		return nil, ErrInvalidDiaryActivity
	}
	return s.dao.Update(id, fields)
}

func (s *DiaryService) Delete(id int64) error {
	return s.dao.SoftDelete(id)
}

func validateDiary(entry *model.DiaryEntry) error {
	if entry.DiaryDate <= 0 {
		return ErrInvalidDiaryDate
	}
	if !model.ValidDiaryMood(entry.Mood) {
		return ErrInvalidDiaryMood
	}
	if !model.ValidDiaryStatus(entry.Status) {
		return ErrInvalidDiaryStatus
	}
	if !model.ValidDiaryActivity(entry.Activity) {
		return ErrInvalidDiaryActivity
	}
	return nil
}

func normalizeDiary(entry *model.DiaryEntry) {
	entry.Title = strings.TrimSpace(entry.Title)
}
