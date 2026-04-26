// Package metrics provides a lightweight, allocation-light latency recorder
// plus simple counters for stress-test scenarios. Pure stdlib.
//
// Design notes:
//   - Recorder stores every sample in a slice guarded by a mutex. At the
//     concurrency levels these tests care about (thousands of ops, not
//     millions/sec), this is simpler than a lock-free histogram and gives
//     us exact percentiles without approximation error.
//   - If a scenario needs to go much higher throughput, swap in HDR histogram
//     later — callers only use the Record / Report interface.
package metrics

import (
	"fmt"
	"io"
	"sort"
	"sync"
	"sync/atomic"
	"time"
)

// Recorder collects latency samples and success/failure counters for a named
// operation (e.g. "login", "ws.join_queue").
type Recorder struct {
	Name string

	mu      sync.Mutex
	samples []time.Duration

	ok    atomic.Uint64
	fail  atomic.Uint64
	bytes atomic.Uint64
}

// NewRecorder creates a Recorder. `hint` pre-allocates sample capacity;
// pass the expected number of samples to avoid slice growth mid-run.
func NewRecorder(name string, hint int) *Recorder {
	if hint <= 0 {
		hint = 1024
	}
	return &Recorder{
		Name:    name,
		samples: make([]time.Duration, 0, hint),
	}
}

// Record logs a single operation's latency and whether it succeeded.
func (r *Recorder) Record(d time.Duration, ok bool) {
	r.mu.Lock()
	r.samples = append(r.samples, d)
	r.mu.Unlock()
	if ok {
		r.ok.Add(1)
	} else {
		r.fail.Add(1)
	}
}

// AddBytes records payload bytes transferred (optional; used for throughput).
func (r *Recorder) AddBytes(n int) {
	if n > 0 {
		r.bytes.Add(uint64(n))
	}
}

// Snapshot is a point-in-time view of a Recorder's stats.
type Snapshot struct {
	Name     string
	Count    int
	OK       uint64
	Fail     uint64
	ErrRate  float64
	Bytes    uint64
	Min      time.Duration
	Max      time.Duration
	Mean     time.Duration
	P50      time.Duration
	P95      time.Duration
	P99      time.Duration
	Duration time.Duration // wall-clock duration the caller passes in
	RPS      float64
}

// Snapshot computes a Snapshot. `elapsed` is the scenario wall-clock duration
// used to compute req/s.
func (r *Recorder) Snapshot(elapsed time.Duration) Snapshot {
	r.mu.Lock()
	samples := make([]time.Duration, len(r.samples))
	copy(samples, r.samples)
	r.mu.Unlock()

	s := Snapshot{
		Name:     r.Name,
		Count:    len(samples),
		OK:       r.ok.Load(),
		Fail:     r.fail.Load(),
		Bytes:    r.bytes.Load(),
		Duration: elapsed,
	}
	if s.Count == 0 {
		return s
	}
	total := s.OK + s.Fail
	if total > 0 {
		s.ErrRate = float64(s.Fail) / float64(total)
	}
	if elapsed > 0 {
		s.RPS = float64(total) / elapsed.Seconds()
	}

	sort.Slice(samples, func(i, j int) bool { return samples[i] < samples[j] })
	s.Min = samples[0]
	s.Max = samples[len(samples)-1]

	var sum time.Duration
	for _, d := range samples {
		sum += d
	}
	s.Mean = sum / time.Duration(len(samples))
	s.P50 = samples[pctIdx(len(samples), 0.50)]
	s.P95 = samples[pctIdx(len(samples), 0.95)]
	s.P99 = samples[pctIdx(len(samples), 0.99)]
	return s
}

func pctIdx(n int, p float64) int {
	if n == 0 {
		return 0
	}
	idx := int(float64(n) * p)
	if idx >= n {
		idx = n - 1
	}
	return idx
}

// PrintReport writes a human-readable report for multiple snapshots.
func PrintReport(w io.Writer, snaps []Snapshot) {
	fmt.Fprintln(w, "===========================================================")
	fmt.Fprintf(w, "%-24s %7s %7s %7s %8s %8s %8s %8s %8s\n",
		"op", "count", "ok", "fail", "rps", "p50", "p95", "p99", "max")
	fmt.Fprintln(w, "-----------------------------------------------------------")
	for _, s := range snaps {
		fmt.Fprintf(w, "%-24s %7d %7d %7d %8.1f %8s %8s %8s %8s\n",
			s.Name, s.Count, s.OK, s.Fail, s.RPS,
			fmtDur(s.P50), fmtDur(s.P95), fmtDur(s.P99), fmtDur(s.Max))
	}
	fmt.Fprintln(w, "===========================================================")
	for _, s := range snaps {
		if s.ErrRate > 0 {
			fmt.Fprintf(w, "  %s error rate: %.2f%% (%d/%d)\n",
				s.Name, s.ErrRate*100, s.Fail, s.OK+s.Fail)
		}
	}
}

func fmtDur(d time.Duration) string {
	switch {
	case d >= time.Second:
		return fmt.Sprintf("%.2fs", d.Seconds())
	case d >= time.Millisecond:
		return fmt.Sprintf("%.1fms", float64(d)/float64(time.Millisecond))
	case d >= time.Microsecond:
		return fmt.Sprintf("%dus", d.Microseconds())
	default:
		return fmt.Sprintf("%dns", d.Nanoseconds())
	}
}
