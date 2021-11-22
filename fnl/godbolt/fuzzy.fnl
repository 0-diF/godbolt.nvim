;  Copyright (C) 2021 Chinmay Dalal
;
;  This file is part of godbolt.nvim.
;
;  godbolt.nvim is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  godbolt.nvim is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with godbolt.nvim.  If not, see <https://www.gnu.org/licenses/>.

(import-macros {: m> : first} :macros)

(local fun vim.fn)
(local pre-display (. (require :godbolt.assembly) :pre-display))
(local execute (. (require :godbolt.execute) :execute))

(fn transform [entry]
  "Get the compiler id"
  {:value (. (vim.split entry " ") 1) :display entry :ordinal entry})

(fn fzf [entries begin end options exec]
  (fun.fzf#run {:source entries
                :window {:width 0.9 :height 0.6}
                :sink (fn [choice]
                        (local compiler (-> choice (vim.split " ") (. 1)))
                        (pre-display begin end compiler options)
                        (if exec
                            (execute begin end compiler options)))}))

; Same as fzf, just s/fzf/skim/g
(fn skim [entries begin end options exec]
  (fun.skim#run {:source entries
                 :window {:width 0.9 :height 0.6}
                 :sink (fn [choice]
                         (local compiler (first (vim.split choice " ")))
                         (pre-display begin end compiler options)
                         (if exec
                             (execute begin end compiler options)))}))

(fn telescope [entries begin end options exec]
  (let [pickers (require :telescope.pickers)
        finders (require :telescope.finders)
        conf (. (require :telescope.config) :values)
        actions (require :telescope.actions)
        actions-state (require :telescope.actions.state)]
    (: (pickers.new {}
                    {:prompt_title "Choose compiler"
                     :finder (finders.new_table {:results entries
                                                 :entry_maker transform})
                     :sorter (conf.generic_sorter nil)
                     :attach_mappings (fn [prompt-bufnr map]
                                        (actions.select_default:replace (fn []
                                                                          (actions.close prompt-bufnr)
                                                                          (local compiler
                                                                                 (. (actions-state.get_selected_entry)
                                                                                    :value))
                                                                          (pre-display begin
                                                                                       end
                                                                                       compiler
                                                                                       options)
                                                                          (if exec
                                                                              (execute begin
                                                                                       end
                                                                                       compiler
                                                                                       options)))))})
       :find)))

(fn fuzzy [picker ft begin end options exec]
  (let [ft (match ft
             :cpp :c++
             x x)
        cmd (string.format "curl https://godbolt.org/api/compilers/%s" ft)]
    (var output [])
    (local jobid
           (fun.jobstart cmd
                         {:on_stdout (fn [_ data _]
                                       (vim.list_extend output data))
                          :on_exit (fn [_ _ _]
                                     (let [final (icollect [k v (ipairs output)]
                                                   (when (not= k 1) v))]
                                       ((match picker
                                          :fzf fzf
                                          :skim skim
                                          :telescope telescope)
                                        final begin end options exec)))}))))

{: fuzzy}
