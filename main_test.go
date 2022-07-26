// Copyright 2022 Contrast Security, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/rogpeppe/go-internal/testscript"
)

func TestMain(m *testing.M) {
	os.Exit(testscript.RunMain(m, map[string]func() int{
		"contrast-go-installer": main1,
	}))
}

func TestScripts(t *testing.T) {
	testscript.Run(t, testscript.Params{
		Dir: "testdata",
		Setup: func(env *testscript.Env) error {
			bin := filepath.Join(env.WorkDir, "bin")
			if err := os.Mkdir(filepath.Join(env.WorkDir, "bin"), 0700); err != nil {
				env.T().Fatal(err)
			}
			env.Setenv("GOBIN", bin)
			return nil
		},
		Cmds: map[string]func(*testscript.TestScript, bool, []string){
			"run-test-server": startServer,
		},
		Condition: func(cond string) (bool, error) {
			switch cond {
			case "real":
				return false, nil
			}

			return false, errors.New("unrecognized condition")
		},
	})
}

// startServer starts a test server to handle downloads and puts the server's
// address in the $baseURL environment variable.
func startServer(ts *testscript.TestScript, neg bool, args []string) {
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		paths := strings.Split(r.RequestURI[1:], "/")
		switch len(paths) {
		case 0:
			w.WriteHeader(500)
		case 1, 2:
			// TODO(GO-1423): we may want these responses to emulate
			// artifactory's behavior and return a list of directory entries,
			// perhaps based on args
			w.WriteHeader(404)
		case 3:
			if paths[2] == "contrast-go" && !neg {
				w.Write([]byte(r.RequestURI))
			} else {
				w.WriteHeader(404)
			}
		}
	}))
	ts.Defer(s.Close)
	ts.Logf("test server listening at: %s", s.URL)

	ts.Setenv("baseURL", s.URL)
}
