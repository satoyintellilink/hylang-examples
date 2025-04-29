(import json)
(import os)
(import sys [argv])
(require hyrule [unless -> as-> defmain ap-with ebranch of])
(import hyrule [pprint parse-args coll?])
(import cytoolz [curry itemmap])

; check commandline arguments are valid
(defn check_args [args]
  (unless (= (. args infile) sys.stdin)
    (unless (os.path.exists (. args infile))
      (raise (ValueError f"infile {(. args infile)} does not exist."))
    )
  )
  (unless (= (. args outfile) sys.stdout)
    (unless (or (os.path.exists (. args outfile)) (os.access (os.path.dirname (os.path.abspath(. args outfile))) os.W_OK))
      (raise (ValueError f"outfile {(. args outfile)} is not writable."))
    )
  )
  (unless (os.path.exists (. args dictfile))
    (raise (ValueError f"dictfile {(. args dictfile)} does not exist."))
  )
)

; read json from either stdin or file
(defn read_json [file]
  (if (= file sys.stdin)
    (json.load file)
    (ap-with
      (open file "r")
      (json.load it)
    )
  )
)

; write json obj to either stdout or file
(defn write_json [file obj]
  (if (= file sys.stdout)
    (json.dump obj file :indent 2 :ensure_ascii False)
    (ap-with
      (open file "w")
      (json.dump obj it :indent 2 :ensure_ascii False)
    )
  )
)

; translate word according to dict
(defn translate [translation_dict word]
  (if (in word translation_dict)
    (. translation_dict [word])
    word
  )
)

; map key of json objects according to function
(defn map_key_deep [translate_func obj]
  (if (coll? obj)
    (ebranch (isinstance obj it)
      (of dict)
        (itemmap
          (fn [item] #((translate_func (. item [0])) (map_key_deep translate_func (. item [1]))))
          obj
        )
      (of list) (list(map ((curry map_key_deep) translate_func) obj))
    )
    obj
  )
)

; read translation dict from file
(defn read_translation_dict [dict_file]
  (dfor i
    (read_json dict_file)
    (. i ["from"])
    (. i ["to"])
  )
)

; main function
(defn main []
  (let
    [
      args (
        parse-args :spec [
          ["-f" "--infile" :type str :help "input file" :default sys.stdin]
          ["-o" "--outfile" :type str :help "output file" :default sys.stdout]
          ["-d" "--dictfile" :type str :help "dict file" :default "dict.json"]
        ]
      )
      translate_key ((curry translate) (read_translation_dict (. args dictfile)))
    ]
    (check_args args)
    (as-> (read_json (. args infile)) output
      (map_key_deep translate_key output)
      (write_json (. args outfile) output)
    )
  )
)

(defmain []
  (main))
