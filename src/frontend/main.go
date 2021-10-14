package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
	"io/ioutil"
)

func httpHandler(w http.ResponseWriter, r *http.Request) {
	var err error
	var hostname string
	resp, err := http.Get(os.Getenv("BACKEND_URL"))
	responseData,err := ioutil.ReadAll(resp.Body)
	fmt.Printf("%s - [%s] %s %s %s\n", hostname, time.Now().Format(time.RFC1123), r.RemoteAddr, r.Method, r.URL)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Fprintf(w, "Backend Responded: %s", string(responseData))
}

func main() {
	fmt.Println("Starting frontend...")
	http.HandleFunc("/", httpHandler)
	log.Fatalln(http.ListenAndServe(":3000", nil))
}