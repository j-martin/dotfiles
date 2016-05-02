(setq user-full-name "Jean-Martin Archer"
  user-mail-address "jm@jmartin.ca")
(add-hook 'focus-out-hook (lambda () (save-some-buffers t)))
(delete-selection-mode 1)
(setq edit-server-url-major-mode-alist '(("github\\.com" . org-mode)))
(editorconfig-mode 1)
(global-auto-revert-mode t)
(global-company-mode 1)
(ws-butler-global-mode 1)
(setq confirm-kill-emacs 'y-or-n-p)
(setq mac-emulate-three-button-mouse t)
(setq paradox-github-token (getenv "PARADOX_TOKEN"))
(setq make-backup-files nil)
(spacemacs/toggle-aggressive-indent-globally-on)
(spacemacs/toggle-camel-case-motion-globally-on)
(spacemacs/toggle-indent-guide-globally-on)
;; (spacemacs/toggle-evil-cleverparens-on)
;; (spacemacs/toggle-smartparens-globally-on)
(setq save-interprogram-paste-before-kill t)
(setq multi-term-program-switches "--login")
(setq x-select-enable-clipboard nil)

(setq custom-file "~/.emacs.d/private/custom-settings.el")
(load custom-file t)

(spacemacs/toggle-syntax-checking-on)
(spacemacs/toggle-truncate-lines-on)
(spacemacs/toggle-vi-tilde-fringe-off)
(set-keyboard-coding-system nil)
(setq powerline-default-separator 'utf-8)
(setq neo-theme 'arrow)
(global-prettify-symbols-mode 1)
(golden-ratio-mode 1)
(menu-bar-mode 1)

(add-hook 'text-mode-hook 'turn-on-auto-fill)
(add-hook 'markdown-mode-hook 'turn-on-auto-fill)
(add-hook 'org-mode-hook 'turn-on-auto-fill)

(setq-default evil-escape-delay 0.3)
(setq-default evil-escape-key-sequence "jk")

(add-hook 'js2-mode-hook (lambda () (push '("function" . ?ƒ) prettify-symbols-alist) (prettify-symbols-mode)))
(setq-default js-indent-level 2)

(define-key evil-insert-state-map (kbd "M-<up>") 'er/expand-region)
(define-key evil-insert-state-map (kbd "M-<down>") 'er/contract-region)
(define-key evil-normal-state-map (kbd "M-<up>") 'er/expand-region)
(define-key evil-normal-state-map (kbd "M-<down>") 'er/contract-region)
(spacemacs/set-leader-keys "oo" 'jm/open-org-dir)
(spacemacs/set-leader-keys "op" 'jm/open-with-sublime)
(spacemacs/set-leader-keys "oi" 'jm/open-with-idea)
(spacemacs/set-leader-keys "on" 'jm/open-with-nvim)
(spacemacs/set-leader-keys "ot" 'jm/insert-today)
(spacemacs/set-leader-keys "oh" 'jm/insert-github-tasks)

(defun jm/open-org-dir ()
  (interactive)
  (helm (list-directory "~/.org/"))
  )

(defun jm/insert-github-tasks ()
  (interactive)
  (insert (shell-command-to-string "$HOME/.bin/org_todo.sh")))

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

(setq org-directory "~/.org/")
(org-agenda-files (list org-directory))
(setq org-capture-templates
  '(("t" "Todo" entry (file+headline "~/.org/gtd.org" "Tasks")
      "* TODO %?\n  %i\n  %a")
     ("j" "Journal" entry (file+datetree "~/.org/journal.org")
       "* %?\nEntered on %U\n  %i\n  %a")))
(setq org-todo-keywords
  '((sequence "TODO(t)" "WAIT(w@/!)" "|" "DONE(d!)" "CANCELED(c@)")))
(use-package org-babel
  :init
  (org-babel-do-load-languages
    'org-babel-load-languages
    '(
       (emacs-lisp . t)
       ))
  )
