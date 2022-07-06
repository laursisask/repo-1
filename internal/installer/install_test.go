package installer

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func Test_install(t *testing.T) {
	var tests = map[string]struct {
		handler http.Handler
		// if non-nil, is called to configure the server
		server func(*httptest.Server) *httptest.Server
		// if the handler lets the file download, save it to this path in a tmp
		// dir; defaults to "contrast-go"
		dst string

		// if non-empty, expect an error containing the string
		expectErr string
	}{
		"simple": {
			handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Write([]byte("some data"))
			}),
		},
		"404": {
			handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(404)
			}),
			expectErr: "no 'v' release found for os/arch",
		},
		"500": {
			handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(500)
			}),
			expectErr: "server did not return 200",
		},
		"EOF from content-length mistach": {
			handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Header().Set("Content-Length", "1000")
				w.WriteHeader(200)
				w.Write([]byte("not 1000 bytes"))
			}),
			expectErr: "couldn't download file",
		},
		"unwriteable dir": {
			handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Write([]byte("some data"))
			}),
			dst:       filepath.Join("dir", "contrast-go"),
			expectErr: "rename",
		},
		"bad connection": {
			handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Write([]byte("some data"))
			}),
			server: func(s *httptest.Server) *httptest.Server {
				s.Close()
				return s
			},
			expectErr: "unexpected connection issue",
		},
		"untrusted cert": {
			handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.Write([]byte("some data"))
			}),
			server: func(s *httptest.Server) *httptest.Server {
				return httptest.NewTLSServer(s.Config.Handler)
			},
			expectErr: "certificate",
		},
		"follows redirect": {
			handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if !strings.Contains(r.RequestURI, "redirect") {
					http.Redirect(w, r, "/redirect", http.StatusMovedPermanently)
					return
				}
				w.Write([]byte("some data"))
			}),
		},
		"follows redirect to error": {
			handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if !strings.Contains(r.RequestURI, "redirect") {
					http.Redirect(w, r, "/redirect", http.StatusMovedPermanently)
					return
				}
				w.WriteHeader(404)
			}),
			expectErr: "no 'v' release found for os/arch",
		},
		"url is correctly formatted": {
			handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.RequestURI == "/v/os-arch/contrast-go" {
					w.Write([]byte("ok"))
					return
				}
				w.WriteHeader(404)
			}),
		},
	}

	for name, test := range tests {
		t.Run(name, func(t *testing.T) {
			s := httptest.NewServer(test.handler)
			if test.server != nil {
				s = test.server(s)
			}
			t.Cleanup(s.Close)

			if test.dst == "" {
				test.dst = "contrast-go"
			}
			dst := filepath.Join(t.TempDir(), test.dst)

			err := install(s.URL, "v", "os", "arch", dst)
			switch {
			case (test.expectErr == "") != (err == nil):
				t.Fatalf("unexpected err: %v", err)

			case test.expectErr != "":
				if !strings.Contains(err.Error(), test.expectErr) {
					t.Fatalf(
						"error did not contain expected string %q:\n%v",
						test.expectErr, err,
					)
				}
			}

			fi, err := os.Stat(dst)
			if test.expectErr != "" {
				if !errors.Is(err, os.ErrNotExist) {
					t.Fatalf("expected file to not exist")
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}

			if fi.Size() < 1 {
				t.Fatal("unexpected 0 length file")
			}

			if fi.Mode()&0100 == 0 {
				t.Fatalf("file with mode %v is not executable", fi.Mode())
			}
		})
	}
}
