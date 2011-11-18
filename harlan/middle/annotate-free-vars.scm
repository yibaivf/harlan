(library
  (harlan middle annotate-free-vars)
  (export annotate-free-vars)
  (import (rnrs) (elegant-weapons helpers))

(define-match annotate-free-vars
  ((module . ,[annotate-decl* -> decl*])
   `(module . ,decl*)))

(define-match annotate-decl*
  (((,tag* ,name* . ,rest*) ...)
   (map (annotate-decl name*)
     `((,tag* ,name* . ,rest*) ...))))

(define-match (annotate-decl globals)
  ((fn ,name ,args ,type ,[annotate-stmt -> stmt fv*])
   (let ((fv* (fold-right remove fv* globals)))
     (if (null? fv*)
         `(fn ,name ,args ,type ,stmt)
         (error 'annotate-free-vars "unbound varaible(s)" fv*))))
  ((extern ,name ,arg-types -> ,type)
   `(extern ,name ,arg-types -> ,type)))

(define-match annotate-stmt
  ((begin ,[stmt* fv**] ...)
   (values `(begin . ,stmt*) (apply union* fv**)))
  ((kernel (((,x* ,t*)
             (,[annotate-expr -> xs* fv**] ,ts*)) ...)
     ,[stmt fv*])
   (let ((fv* (fold-right remove fv* x*)))
     (values
       `(kernel (((,x* ,t*) (,xs* ,ts*)) ...)
          (free-vars . ,fv*) ,stmt)
       (apply union* fv* fv**))))
  ((return ,[annotate-expr -> e fv*])
   (values `(return ,e) fv*))
  ((if ,[annotate-expr -> test tfv*] ,[conseq cfv*])
   (values `(if ,test ,conseq) (union tfv* cfv*)))
  ((if ,[annotate-expr -> test tfv*] ,[conseq cfv*] ,[alt afv*])
   (values `(if ,test ,conseq ,alt)
     (union* tfv* cfv* afv*)))
  ((do ,[annotate-expr -> e fv*])
   (values `(do ,e) fv*))
  ((let ((,x* ,[annotate-expr -> e* fv**]) ...) ,[stmt fv*])
   (let ((fv* (fold-right remove fv* x*)))
     (values `(let ((,x* ,e*) ...) ,stmt)
       (apply union* fv* fv**))))
  ((while ,[annotate-expr -> e efv*] ,[stmt sfv*])
   (values `(while ,e ,stmt) (union efv* sfv*)))
  ((for (,x ,[annotate-expr -> start sfv*]
          ,[annotate-expr -> end efv*])
     ,[stmt bfv*])
   (let ((bfv* (remq x bfv*)))
     (values `(for (,x ,start ,end) ,stmt)
       (union* bfv* sfv* efv*))))
  ((set! ,[annotate-expr -> x xfv*] ,[annotate-expr -> e efv*])
   (values `(set! ,x ,e) (union xfv* efv*)))
  ((print ,[annotate-expr -> e fv*])
   (values `(print ,e) fv*))
  ((assert ,[annotate-expr -> e fv*])
   (values `(assert ,e) fv*)))

(define-match annotate-expr
  ((int ,n) (values `(int ,n) '()))
  ((u64 ,n) (values `(u64 ,n) '()))
  ((float ,f) (values `(float ,f) '()))
  ((str ,s) (values `(str ,s) '()))
  ((var ,t ,x) (values `(var ,t ,x) `(,x)))
  ((c-expr ,t ,x) (values `(c-expr ,t ,x) `()))
  ((cast ,t ,[e fv*]) (values `(cast ,t ,e) fv*))
  ((call ,[rator fv*] ,[rand* fv**] ...)
   (values
     `(call ,rator . ,rand*)
     (apply union* fv* fv**)))
  ((let ((,x* ,[e* fv**]) ...) ,[expr fv*])
   (let ((fv* (fold-right remove fv* x*)))
     (values `(let ((,x* ,e*) ...) ,expr)
       (apply union* fv* fv**))))
  ((if ,[test tfv*] ,[conseq cfv*] ,[alt afv*])
   (values `(if ,test ,conseq ,alt)
     (union* tfv* cfv* afv*)))
  ((sizeof ,t) (values `(sizeof ,t) '()))
  ((addressof ,[e fv*]) (values `(addressof ,e) fv*))
  ((,op ,[lhs lfv*] ,[rhs rfv*])
   (guard (or (binop? op) (relop? op)))
   (values `(,op ,lhs ,rhs) (union lfv* rfv*)))
  ((vector-ref ,t ,[v vfv*] ,[i ifv*])
   (values `(vector-ref ,t ,v ,i) (union vfv* ifv*))))

(define union
  (lambda (s1 s2)
    (cond
      [(null? s1) s2]
      [(member (car s1) s2) (union (cdr s1) s2)]
      [else (cons (car s1) (union (cdr s1) s2))])))

(define union*
  (lambda args
    (union*-aux args)))

(define union*-aux
  (lambda (args)
    (cond
      [(null? args) '()]
      [(null? (cdr args)) (car args)]
      [else (union (union (car args) (cadr args))
                   (union*-aux (cddr args)))])))

;; end library
)
