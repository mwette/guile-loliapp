;; module dependencies

(use-modules (ice-9 match))
(use-modules ((srfi srfi-1) #:select (fold every lset-union)))
(use-modules ((system base compile) #:select (compiled-file-name)))
(use-modules (ice-9 pretty-print))
(define pp pretty-print)
(define (sf fmt . args) (apply simple-format #t fmt args))

(define ignore-me
  '((system syntax internal)
    (compile compile-file)
    (guile-user) ;; ???
    ))

(define (module-filename mod-spec)
  (fold
   (lambda (pfix path)
     (if path path
         (let ((path
                (string-append
                 pfix "/" (string-join (map symbol->string mod-spec) "/")
                 ".scm")))
         (and (access? path R_OK) path))))
   #f %load-path))

(define (spec-dep spec seed)
  (let ((sdl (match spec (((sdl ...) . _0) sdl) ((sdl ...) sdl))))
    (if (member sdl ignore-me) seed (cons sdl seed))))

(define (mod-deps exp seed)
  (let loop ((deps seed) (tail (cddr exp)))
    (match tail
      ('() deps)
      (`(#:use-module ,spec . ,rest)
       (loop (spec-dep spec deps) rest))
      (`(#:autoload ,spec ,procs . ,rest)
       (loop (spec-dep spec deps) rest))
      ((key val . rest)
       (loop deps rest)))))

(define (probe-module-file filename)
  (call-with-input-file filename
    (lambda (port)
      (let loop ((deps '()) (exp (read port)))
	(match exp
	  ((? eof-object?) (reverse deps))
          (`(define-module . ,_0) (loop (mod-deps exp deps) (read port)))
          (`(use-modules . ,specs) (loop (fold spec-dep deps specs) (read port)))
          (__ (loop deps (read port))))))))

;; mod-name : '(ice-9 regex)
(define (probe-module mod-name)
  (sf "probe ~S => ~S\n" mod-name (module-filename mod-name))
  ;;(sleep 1)
  (cons mod-name (probe-module-file (module-filename mod-name))))

(define (get-dict mod-name)
  (let loop ((dict '()) (todo (list mod-name)))
    (cond
     ((null? todo)
      (reverse dict))
     ((assoc-ref dict (car todo))
      (loop dict (cdr todo)))
     (else
      (let ((entry (probe-module (car todo))))
        (loop (cons entry dict) (append (cdr entry) todo)))))))

#|
(define (get-conns dict)
  (let loop ((cns '()) (dis dict))
    (if (null? dis) cns
        (loop (append (map (lambda (dep) (cons (caar dis) dep)) (cdar dis)) cns)
              (cdr dis)))))

;; => (values pre rpost lks)
(define (gen-orders nodes conns)
  (let loop ((pre '()) (rpost '()) (lks '())
             (ix 1) (jx (length nodes))
             (nd #f) (cns '())
             (stk '()) (uvs nodes))
    (cond
     ((pair? cns)
      (cond
       ((and (eq? (caar cns) nd) (not (assq (cdar cns) pre)))
        (let* ((dst (cdar cns))
               (pre (acons dst ix pre))
               (uvs (delq dst uvs))
               (stk (acons nd cns stk)))
          (loop pre rpost lks ix jx nd (cdr cns) stk uvs)))
       (else
        (loop pre rpost lks ix jx nd (cdr cns) stk uvs))))
     ((pair? stk)
      (loop pre (acons nd jx rpost) lks ix (1- jx) (caar stk) (cdar stk)
            (cdr stk) uvs))
     ((pair? uvs)
      (let* ((rpost (if nd (acons nd jx rpost) rpost))
          (jx (if nd (1- jx) jx))
             (nd (car uvs))
             (uvs (cdr uvs)))
        (loop (acons nd ix pre) rpost lks (1+ ix) jx nd conns stk uvs)))
     (else
      (values pre (acons nd jx rpost) lks)))))
|#

(define (tsort filed filel)
  (define (covered? deps done) (every (lambda (e) (member e done)) deps))
  (let loop ((done '()) (hd '()) (tl filel))
    (if (null? tl)
        (if (null? hd) done (loop done '() hd))
        (cond
         ((not (assq-ref filed (car tl)))
          (loop (cons (car tl) done) hd (cdr tl)))
         ((covered? (assq-ref filed (car tl)) done)
          (loop (cons (car tl) done) hd (cdr tl)))
         (else
          (loop done (cons (car tl) hd) (cdr tl)))))))

;;(pp (get-dict '(nyacc lang c99 munge)))

(let* (
       ;;(module '(nyacc lang c99 munge))
       (module '(ice-9 boot-9))
       (depd (get-dict module))
       (all (apply lset-union equal? depd))
       (seq (reverse (tsort depd all)))
       (scmfl (map
               (lambda (m) (string-append
                            (string-join (map symbol->string m) "/") ".scm"))
               seq))
       (scmpl (map %search-load-path scmfl))
       (gopl (map compiled-file-name scmpl))
       ;;(conns (get-conns dict))
       ;;(nodes (delete-duplicates (cons (caar dict) (map cdr conns))))
       )
  ;;(pp scmfl)
  ;;(pp scmpl)
  (pp gopl)
  #|
  (pp "====")
  (pp conns)
  (pp "====")
  (pp nodes)
  |#
  #f)

;; --- last line ---
