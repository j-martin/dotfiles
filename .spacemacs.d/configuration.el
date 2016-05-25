(add-hook 'focus-out-hook (lambda () (save-some-buffers t)))
(setq confirm-kill-emacs 'y-or-n-p)
(setq mac-emulate-three-button-mouse t)
(setq x-select-enable-clipboard nil)
(setq make-backup-files nil)
(spacemacs/toggle-indent-guide-globally-on)
;; (spacemacs/toggle-camel-case-motion-globally-on)
;; (spacemacs/toggle-evil-cleverparens-on)
;; (spacemacs/toggle-smartparens-globally-on)
(setq save-interprogram-paste-before-kill t)
(setq multi-term-program-switches "--login")

(setq custom-file "~/.spacemacs.d/custom-configuration.el")
(load custom-file t)

(setq edit-server-url-major-mode-alist '(("github\\.com" . org-mode)))
(setq paradox-github-token (shell-command "keyring get system github_paradox"))

(spacemacs/toggle-syntax-checking-on)
(spacemacs/toggle-truncate-lines-on)
(spacemacs/toggle-vi-tilde-fringe-off)
(setq powerline-default-separator 'utf-8)
(set-keyboard-coding-system nil)
(setq neo-theme 'arrow)
(global-prettify-symbols-mode 1)
(golden-ratio-mode 1)
(menu-bar-mode 1)
(setq-default avy-all-windows 'all-frames)

(global-whitespace-mode 1)
(setq fill-column 120)
(setq whitespace-line-column 160)
(setq-default
  tab-width 2
  indent-tabs-mode nil
  fci-rule-column 120
  )
(custom-set-faces
  '(company-tooltip-common ((t (:inherit company-tooltip :weight bold :underline nil))))
  '(company-tooltip-common-selection ((t (:inherit company-tooltip-selection :weight bold :underline nil))))
  '(whitespace-line ((t nil)))
  '(whitespace-newline ((t (:foreground "gray30"))))
  '(whitespace-space ((t (:foreground "gray30"))))
  '(whitespace-trailing ((t (:background "saddle brown" :foreground "gray100")))))

(setq ns-use-srgb-colorspace nil)

(setq theming-modifications '((spacemacs-dark (default :foreground "#eeeeee"))))
(spacemacs/update-theme)

(delete-selection-mode 1)
(editorconfig-mode 1)
(global-auto-revert-mode t)
(global-company-mode 1)
(ws-butler-global-mode 1)
(global-evil-mc-mode 1)
(setq-default abbrev-mode t)
(setq save-abbrevs 'silently)

(add-hook 'text-mode-hook 'turn-on-auto-fill)
(add-hook 'markdown-mode-hook 'turn-on-auto-fill)
(add-hook 'org-mode-hook 'turn-on-auto-fill)

(add-hook 'emacs-lisp-mode-hook #'aggressive-indent-mode)
(add-hook 'clojure-mode-hook #'aggressive-indent-mode)
(add-hook 'shell-script-mode-hook #'aggressive-indent-mode)

(defun jm/pretty-symbols ()
  "make some word or string show as pretty Unicode symbols"
  (setq prettify-symbols-alist
    '(
       ("lambda" . 955) ; λ
       ("->" . 8594)    ; →
       ("=>" . 8658)    ; ⇒
       ("function" . ?ƒ)
       )))
(add-hook 'lisp-mode-hook 'jm/pretty-symbols)
(add-hook 'org-mode-hook 'jm/pretty-symbols)
(add-hook 'js2-mode-hook 'jm/pretty-symbols)
(add-hook 'scala-mode-hook 'jm/pretty-symbols)
(add-hook 'coffee-mode-hook 'jm/pretty-symbols)
(add-hook 'lua-mode-hook 'jm/pretty-symbols)

(setq-default evil-escape-delay 0.3)
(setq-default evil-escape-key-sequence "jk")

(setq-default js-indent-level 2)

(setq magit-repository-directories '("~/Work/"))
(setq-default vc-follow-symlinks t)

(use-package org-babel
  :init
  (org-babel-do-load-languages
    'org-babel-load-languages
    '(
    (emacs-lisp . t)
    (sh . t)
    (python . t))))

(setq org-directory "~/.org/")
(org-agenda-files (list org-directory))

;; (setq org-todo-keywords
;;   '((sequence "TODO(t)" "WAIT(w@/!)" "|" "DONE(d!)" "CANCELED(c@)")))

(setq org-capture-templates
  '(
     ("t" "Todo" entry (file+headline "~/.org/todo.org" "Tasks")
       "* TODO %?\n  %i\n %a")
     ("T" "Todo with clipboard" entry (file+headline "~/.org/todo.org" "Tasks")
       "* TODO %?\n  %i\n %c\n %a")
     ("w" "Article/Page to read" entry (file+headline "~/.org/learning.org" "Article")
       "* %?\n  %i\n %c\n %a")
     ("j" "Journal" entry (file+datetree "~/.org/journal.org")
       "* %?\nEntered on %U\n  %i\n %a")
     ("J" "Journal with Clipboard" entry (file+datetree "~/.org/journal.org")
       "* %?\nEntered on %U\n  %i\n %c\n %a")
     ))

(define-key evil-insert-state-map (kbd "M-<up>") 'er/expand-region)
(define-key evil-insert-state-map (kbd "M-<down>") 'er/contract-region)
(define-key evil-normal-state-map (kbd "M-<up>") 'er/expand-region)
(define-key evil-normal-state-map (kbd "M-<down>") 'er/contract-region)
(global-set-key [f8] 'neotree-projectile-action)

(global-set-key (kbd "s-<left>") 'beginning-of-line)
(global-set-key (kbd "s-<right>") 'end-of-line)
(define-key evil-insert-state-map (kbd "C-a") 'beginning-of-line)
(define-key evil-insert-state-map (kbd "C-e") 'end-of-line)

(spacemacs/set-leader-keys "oo" 'jm/helm-org-dir)
(spacemacs/set-leader-keys "oh" 'jm/helm-home-dir)
(spacemacs/set-leader-keys "op" 'jm/open-with-sublime)
(spacemacs/set-leader-keys "oi" 'jm/open-with-idea)
(spacemacs/set-leader-keys "on" 'jm/open-with-nvim)
(spacemacs/set-leader-keys "ot" 'jm/insert-today)
(spacemacs/set-leader-keys "og" 'jm/org-github-todo)

(defun jm/helm-org-dir ()
  (interactive)
  (helm-find-files-1 (expand-file-name "~/.org/")))

(defun jm/helm-home-dir ()
  (interactive)
  (helm-find-files-1 (expand-file-name "~/")))

(defun jm/org-github-todo ()
  (interactive)
  (insert (shell-command-to-string "$HOME/.bin/org_todo.sh  2> /dev/null")))

(defun jm/insert-today ()
  (interactive)
  (insert (shell-command-to-string "/bin/date \"+%Y-%m-%d\"")))

(defun jm/get-column ()
  (number-to-string (+ (current-column) 1)))

(defun jm/get-line-number ()
  (number-to-string (line-number-at-pos)))

(defun jm/open-with-line (app)
  (when buffer-file-name
    (save-buffer)
    (shell-command (concat app " \"" buffer-file-name ":" (jm/get-line-number) "\""))))

(defun jm/open-with-line-column (app)
  (when buffer-file-name
    (save-buffer)
    (shell-command (concat app " \"" buffer-file-name ":" (jm/get-line-number) ":" (jm/get-column) "\""))))

(defun jm/open-with-line-column-vim (app)
  (when buffer-file-name
    (shell-command (concat app " \"" buffer-file-name "\" \"+normal " (jm/get-line-number) "G" (jm/get-column) "|\""))))

(defun jm/open-with-reveal (app)
  (shell-command (concat "osascript -e 'tell application \"" app "\" to activate'")))

(defun jm/open-with-sublime ()
  (interactive)
  (jm/open-with-line-column "/usr/local/bin/subl"))

(defun jm/open-with-idea ()
  (interactive)
  (jm/open-with-reveal "IntelliJ IDEA")
  (jm/open-with-line "/usr/local/bin/idea"))

(defun jm/open-with-nvim ()
  (interactive)
  (jm/open-with-line-column-vim "/usr/local/Cellar/neovim-dot-app/HEAD/bin/gnvim"))

(define-key ctl-x-map "\C-i"
  #'endless/ispell-word-then-abbrev)

(defun endless/simple-get-word ()
  (car-safe (save-excursion (ispell-get-word nil))))

(defun endless/ispell-word-then-abbrev (p)
  "Call `ispell-word', then create an abbrev for it.
With prefix P, create local abbrev. Otherwise it will
be global.
If there's nothing wrong with the word at point, keep
looking for a typo until the beginning of buffer. You can
skip typos you don't want to fix with `SPC', and you can
abort completely with `C-g'."
  (interactive "P")
  (let (bef aft)
    (save-excursion
      (while (if (setq bef (endless/simple-get-word))
                 ;; Word was corrected or used quit.
                 (if (ispell-word nil 'quiet)
                     nil ; End the loop.
                   ;; Also end if we reach `bob'.
                   (not (bobp)))
               ;; If there's no word at point, keep looking
               ;; until `bob'.
               (not (bobp)))
        (backward-word)
        (backward-char))
      (setq aft (endless/simple-get-word)))
    (if (and aft bef (not (equal aft bef)))
        (let ((aft (downcase aft))
              (bef (downcase bef)))
          (define-abbrev
            (if p local-abbrev-table global-abbrev-table)
            bef aft)
          (message "\"%s\" now expands to \"%s\" %sally"
                   bef aft (if p "loc" "glob")))
      (user-error "No typo at or before point"))))
