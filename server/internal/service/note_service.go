package service

import (
	"errors"
	"log"

	"essaypad/internal/model"
	"essaypad/internal/store"
)

type NoteService struct {
	dao *store.NoteDAO
}

func NewNoteService(dao *store.NoteDAO) *NoteService {
	return &NoteService{dao: dao}
}

var ErrInvalidCategory = errors.New("invalid category")
var ErrTitleEmpty = errors.New("title is required")

func (s *NoteService) Create(n *model.Note) (int64, error) {
	if !model.ValidCategory(n.Category) {
		return 0, ErrInvalidCategory
	}
	if n.Title == "" {
		return 0, ErrTitleEmpty
	}
	id, err := s.dao.Create(n)
	if err != nil {
		return 0, err
	}
	if n.Category == model.CategoryDraft {
		if _, err := s.dao.TrimCategoryToLimit(model.CategoryDraft, 20); err != nil {
			log.Printf("NoteService.Create trim draft failed: %v", err)
		}
	}
	return id, nil
}

func (s *NoteService) Get(id int64) (*model.Note, error) {
	return s.dao.Get(id)
}

func (s *NoteService) List(category, page, pageSize int) ([]*model.Note, int, error) {
	if !model.ValidCategory(category) {
		return nil, 0, ErrInvalidCategory
	}
	return s.dao.List(category, page, pageSize)
}

func (s *NoteService) Update(id int64, title, content string, category int) error {
	if !model.ValidCategory(category) {
		return ErrInvalidCategory
	}
	return s.dao.Update(id, title, content, category)
}

func (s *NoteService) Delete(id int64) error {
	return s.dao.SoftDelete(id)
}
