package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
)

func httpHandler(w http.ResponseWriter, r *http.Request) {
	var err error
	var hostname, backend_url string

	hostname, err = os.Hostname()
	if err != nil {
		log.Fatalln(err)
	}
	backend_url = os.Getenv("BACKEND_URL")
	fmt.Printf("Requesting BACKEND_URL: %s\n", backend_url)
	resp, err := http.Get(backend_url)
	if err != nil {
		fmt.Printf("Backend Failed to respond: %s", err)
		fmt.Fprintf(w, "Hello I'm frontend: %s\nBackend Failed to respond: %s", hostname, err)
	} else {
		responseData, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			fmt.Printf("Backend Failed to respond: %s", err)
			fmt.Fprintf(w, "Hello I'm frontend: %s\nBackend Failed to respond: %s", hostname, err)
		} else {
			fmt.Printf("Backend responded: %s", string(responseData))
			fmt.Fprintf(w, "Hello I'm frontend: %s\nBackend responded: %s", hostname, string(responseData))
		}
	}
}

func main() {
	fmt.Println("Starting frontend...")
	http.HandleFunc("/", httpHandler)
	log.Fatalln(http.ListenAndServe(":3000", nil))
}
