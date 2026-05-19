package handler

import "fmt"

func Handle(name string) string {
	return fmt.Sprintf("Hello, %s!", name)
}
