package function

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"my-service/pkg/handler"
)

func Run() {
	port := os.Getenv("FISSION_FUNCTION_PORT")
	if port == "" {
		port = "8888"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, handler.Handle(r.URL.Path))
	})

	addr := ":" + port
	log.Printf("fission function listening on %s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}
