package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

func httpHandler(w http.ResponseWriter, r *http.Request) {
	var hostname string
	var err error
	hostname, err = os.Hostname()
	if err != nil {
		log.Fatalln(err)
	}
	fmt.Printf("%s - [%s] %s %s %s\n", hostname, time.Now().Format(time.RFC1123), r.RemoteAddr, r.Method, r.URL)
	fmt.Fprintf(w, "Backend Response: %s", hostname)
}

func main() {
	fmt.Println("Starting backend...")
	http.HandleFunc("/", httpHandler)
	log.Fatalln(http.ListenAndServe(":3000", nil))
}