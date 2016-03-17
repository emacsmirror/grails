;;; grails.el --- Minor mode for Grails projects
;;
;; Copyright (c) 2016 Alessandro Miliucci
;;
;; Authors: Alessandro Miliucci <lifeisfoo@gmail.com>
;; Version: 0.2.0
;; URL: https://github.com/lifeisfoo/emacs-grails
;; Package-Requires: ((emacs "24"))

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Description:

;; Grails.el is a minor mode that allows an easy
;; navigation of Gails projects.  It allows jump to a model, to a view,
;; to a controller or to a service.
;;
;; For more details, see the project page at
;; https://github.com/lifeisfoo/emacs-grails
;;
;; Installation:
;;
;; Copy this file to to some location in your Emacs load path.  Then add
;; "(require 'grails)" to your Emacs initialization (.emacs,
;; init.el, or something).
;;
;; Example config:
;;
;;   (require 'grails)

;; Then, to auto enable grails mode, create a .dir-locals.el file
;; in the root of the grails project with this configuration:

;; ((groovy-mode (grails . 1))
;;  (html-mode (grails . 1))
;;  (java-mode (grails . 1)))

;; In this way, the grails mode will be auto enabled when any of
;; these major modes are loaded (only in this directory tree - the project tree)
;; (you can attach it to other modes if you want).

;; The first time that this code is executed, Emacs will show a security
;; prompt: answer "!" to mark code secure and save your decision.
;; (a configuration line is automatically added to your .emacs file)

;; In order to have grails minor mode always enabled inside your project tree,
;; place inside your `.dir-locals.el`:

;;   ((nil . ((grails . 1))))
;;

;;; Code:

(defvar grails-dir-name-by-type
  '(("view" "views")
    ("controller" "controllers")
    ("domain" "domain")
    ("service" "services")))
;; TODO: refactor
;; only supported by jump method
(defvar grails-dir-name-by-type-s
  '((controller "controllers")
    (domain "domain")
    (service "services")))

(defvar grails-postfix-by-type-s
  '((view ".gsp")
    (controller "Controller.groovy")
    (domain ".groovy")
    (service "Service.groovy")))

(defun grails-dir-by-type-and-name (type class-name base-path)
  "Return the file path (string) for the type and the class-name.
  
   E.g. type='domain, class-name=User and base-path=/prj/grails-app/
        will output /prj/grails-app/domain/User.groovy
"
  (concat
   base-path
   (car (cdr (assoc type grails-dir-name-by-type-s)))
   "/"
   class-name
   (car (cdr (assoc type grails-postfix-by-type-s)))))

(defun grails-extract-name (controller-file-path start-from ending-regex)
  "Transform MyClassController.groovy to MyClass, or my/package/MyClassController.groovy to my/package/MyClass."
  (let ((end (string-match ending-regex (substring controller-file-path start-from nil))))
    (substring (substring controller-file-path start-from nil) 0 end)))

(defun grails-clean-name (file-name)
  "Detect current file type and extract it's clean class-name"
  (let ((start (string-match "/grails-app/" file-name)))
    (let ((end (match-end 0)))
      (let ((in-grails-path (substring file-name end nil))) ;; substring that follow 'grails-app/' to the end
	(let ((dir-type (substring in-grails-path (string-match "^[a-zA-Z]+" in-grails-path) (match-end 0))))
	  (cond ((string= dir-type "controllers") (grails-extract-name in-grails-path (+ 1 (match-end 0)) "Controller\.groovy"))
		((string= dir-type "domain") (grails-extract-name in-grails-path (+ 1 (match-end 0)) "\.groovy"))
		((string= dir-type "views") (error "Jumping from views isn't yet supported")) ;; TODO: not yet implemented 
		((string= dir-type "services") (grails-extract-name in-grails-path (+ 1 (match-end 0)) "Service\.groovy"))
		(t (error "File not recognized")))
	  )))))

(defun grails-app-base (path)
  "Get the current grails app base path /my/abs/path/grails-app/ if exist, else nil"
  (let ((start (string-match "/grails-app/" path)))
    (if start
	(substring path 0 (match-end 0))
      () ;; if this is not a grails app return nil
      )))

(defun grails-find-file-auto (grails-type current-file)
  "Generate the relative file path for the current-file and grails-type.

   grails-type is a symbol (e.g. 'domain, 'controller, 'service)
   current-file is a file path
      
   E.g. (grails-find-file-auto 
          'domain'
          '~/prj/grails-app/controllers/UserController.groovy')
   Will output: '~/prj/grails-app/domain/User.groovy'

"
  (let ((base-path (grails-app-base current-file))
	(class-name (grails-clean-name current-file)))
    (if (assoc grails-type grails-dir-name-by-type-s)
	(grails-dir-by-type-and-name grails-type class-name base-path)
      (error "Type not recognized"))))

(defmacro grails-fun-gen-from-file (grails-type)
  (let ((funsymbol (intern (concat "grails-" (symbol-name grails-type) "-from-file"))))
    `(defun ,funsymbol () (interactive) (switch-to-buffer
					 (find-file-noselect
					  (grails-find-file-auto
					   ',grails-type (buffer-file-name)))))))

(defmacro grails-fun-gen-from-name (grails-type)
  (let ((funsymbol (intern (concat "grails-" grails-type "-from-name"))))
    `(defun ,funsymbol () (interactive)
	    (let ((x
		   (read-file-name
		    "Enter file name:"
		    (concat
		     (grails-app-base (buffer-file-name))
		     ,(concat (car (cdr (assoc grails-type grails-dir-name-by-type)))  "/")))))
	      (switch-to-buffer
	       (find-file-noselect x))))))

(defun grails-key-map ()
  (let ((keymap (make-sparse-keymap)))
    (define-key keymap (kbd "C-c - d") (grails-fun-gen-from-file domain))
    (define-key keymap (kbd "C-c - c") (grails-fun-gen-from-file controller))
    (define-key keymap (kbd "C-c - s") (grails-fun-gen-from-file service))
    (define-key keymap (kbd "C-c - n d") (grails-fun-gen-from-name "domain"))
    (define-key keymap (kbd "C-c - n c") (grails-fun-gen-from-name "controller"))
    (define-key keymap (kbd "C-c - n s") (grails-fun-gen-from-name "service"))
    (define-key keymap (kbd "C-c - n v") (grails-fun-gen-from-name "view"))
    keymap))

;;;###autoload
(define-minor-mode grails
  "Grails minor mode.
     With no argument, this command toggles the mode.
     Non-null prefix argument turns on the mode.
     Null prefix argument turns off the mode.
     When Grails minor mode is enabled you have some
     shortcut to fast navigate a Grails project."
  :init-value nil
  :lighter " Grails"
  :keymap (grails-key-map)
  :group 'grails)

(provide 'grails)

;;; grails.el ends here
