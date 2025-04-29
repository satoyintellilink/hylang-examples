(import json)
(import os)
(import base64)
(import hashlib)
(import sys [argv])
(require hyrule [unless -> as-> defmain ap-with ebranch of])
(import hyrule [pprint parse-args coll?])
(import cytoolz [curry itemmap valmap])
(import cryptography.fernet [Fernet])

; check commandline arguments are valid
(defn check_args [args]
  (unless (= (. args infile) sys.stdin)
    (unless (os.path.exists (. args infile))
      (raise (ValueError f"infile {(. args infile)} does not exist."))
    )
  )
  (unless (. args password)
    (raise (ValueError f"password must be set."))
  )
  (unless (= (. args outfile) sys.stdout)
    (unless (or (os.path.exists (. args outfile)) (os.access (os.path.dirname (os.path.abspath(. args outfile))) os.W_OK))
      (raise (ValueError f"outfile {(. args outfile)} is not writable."))
    )
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

; ref: https://stackoverflow.com/questions/44432945/generating-own-key-with-python-fernet
; generate fernet key
(defn gen_fernet_key [password]
  (let
    [
      hlib (hashlib.md5)
    ]
    (hlib.update (.encode password))
    (-> hlib
        (.hexdigest)
        (.encode "latin-1")
        (base64.urlsafe_b64encode))
  )
)

; encrypt string with fernet
; text must be string.
(defn fernet_encrypt [fernet_obj text]
  (ebranch (isinstance text it)
    (of str)
      (.decode (fernet_obj.encrypt (.encode text)))
  )
)

; map key of json objects according to function
(defn map_value_deep [translate_func obj]
  (if (coll? obj)
    (ebranch (isinstance obj it)
      (of dict)
        (valmap ((curry map_value_deep)translate_func) obj)
      (of list) (list(map ((curry map_value_deep) translate_func) obj))
    )
    (translate_func obj)
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
          ["-p" "--password" :type str :help "password"]
        ]
      )
    ]
    (check_args args)
    (let
      [
        key (gen_fernet_key (. args password))
        fernet_obj (Fernet key)
      ]
      (as-> (read_json (. args infile)) output
        (map_value_deep ((curry fernet_encrypt) fernet_obj) output)
        (write_json (. args outfile) output)
      )
    )
  )
)

(defmain []
  (main))
