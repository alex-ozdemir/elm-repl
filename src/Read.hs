module Read (input) where

import qualified Data.Char as Char
import Data.Functor ((<$>))
import qualified Data.List as List
import Text.Parsec (Parsec, (<|>), anyChar, char, choice, eof, many, many1,
                    manyTill, parse, satisfy, space, spaces, string)

import qualified Input


type Parser = Parsec String ()


input :: String -> Input.Input
input string =
  case parse result "" string of
    Right action ->
        action

    Left errorMessage ->
        Input.Meta (Input.Help (Just (show errorMessage)))


result :: Parser Input.Input
result =
  do  spaces
      choice
        [ do  eof
              return Input.Skip
        , do  char ':'
              Input.Meta <$> command
        , do  string <- many anyChar
              return (Input.Code (extractCode string))
        ]


-- PARSE META

command :: Parser Input.Command
command =
  let
    ok cmd =
        eof >> return cmd
  in
  do  flag <- many1 notSpace
      spaces
      case flag of
        "exit"  -> ok Input.Exit
        "reset" -> ok Input.Reset
        "help"  -> ok (Input.Help Nothing)
        "flags" -> ok (Input.InfoFlags Nothing) <|> flags
        _       -> return $ Input.Help (Just flag)


flags :: Parser Input.Command
flags =
  do  flag <- many1 notSpace
      case flag of
        "add"    -> srcDirFlag Input.AddFlag
        "remove" -> srcDirFlag Input.RemoveFlag
        "list"   -> return Input.ListFlags
        "clear"  -> return Input.ClearFlags
        _        -> return (Input.InfoFlags (Just flag))
  where
    srcDirFlag ctor =
      do  many1 space
          ctor <$> srcDir


notSpace :: Parser Char
notSpace =
    satisfy (not . Char.isSpace)


srcDir :: Parser String
srcDir =
  do  string "--src-dir="
      dir <- manyTill anyChar (choice [ space >> return (), eof ])
      return ("--src-dir=" ++ dir)


-- PARSE CODE

extractCode :: String -> (Maybe Input.DefName, String)
extractCode rawInput =
    (extractDefName rawInput, rawInput)


extractDefName :: String -> Maybe Input.DefName
extractDefName src
  | List.isPrefixOf "import " src =
      let
        getFirstCap tokens =
            case tokens of
              token@(c:_) : rest ->
                  if Char.isUpper c then token else getFirstCap rest
              _ -> src
      in
        Just (Input.Import (getFirstCap (words src)))

  | List.isPrefixOf "type alias " src =
      let
        name = takeWhile (/=' ') (drop 11 src)
      in
        Just (Input.DataDef name)

  | List.isPrefixOf "type " src =
      let
        name = takeWhile (/=' ') (drop 5 src)
      in
        Just (Input.DataDef name)

  | otherwise =
      case break (=='=') src of
        (_,"") -> Nothing

        (beforeEquals, _:c:_) ->
            if Char.isSymbol c || hasLet beforeEquals || hasBrace beforeEquals
                then Nothing
                else Just $ Input.VarDef (declName beforeEquals)

        _ -> error errorMessage

      where
        errorMessage =
            "Internal error in elm-repl function Parse.mkCode\n\
            \Please submit bug report to <https://github.com/elm-lang/elm-repl/issues>"

        declName pattern =
            case takeWhile Char.isSymbol $ dropWhile (not . Char.isSymbol) pattern of
              "" -> takeWhile (/=' ') pattern
              op -> op


hasLet :: String -> Bool
hasLet body =
    elem "let" $ map token (words body)
  where
    isVarChar c =
        Char.isAlpha c || Char.isDigit c || elem c "_'"

    token word =
        takeWhile isVarChar $ dropWhile (not . Char.isAlpha) word


hasBrace :: String -> Bool
hasBrace body =
    elem '{' body
