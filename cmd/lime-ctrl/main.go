package main

import (
	"fmt"
	"net/http"
)

func main() {
	fmt.Println("Starting lime-ctrl...")
	
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})
	
	http.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})
	
	http.HandleFunc("/api/execute", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"result": "Code execution simulated", "output": "Hello from MicroVM!"}`))
	})
	
	go http.ListenAndServe(":8081", nil)
	http.ListenAndServe(":8082", nil)
}
