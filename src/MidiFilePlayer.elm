module MidiFilePlayer exposing (..)

{-
  Proof of concept of a MIDI audio player using an embedded MIDI player module

  This allows buttons of start/pause/continue/reset

  in order to contol the playing of the MIDI file
  (again played by means of soundfonts and Web-Audio through elm ports)

-}

import Html exposing (Html, div, button, input, text, progress)
import Html.Events exposing (onClick)
import Html.Attributes exposing (src, type', style, value, max)
import Http exposing (..)
import Html.App as Html
import Task exposing (..)
import String exposing (..)
import Result exposing (Result)
import CoMidi exposing (normalise, parse)
import MidiTypes exposing (MidiEvent(..), MidiRecording)
import Midi.Track exposing (..)
import Midi.Player exposing (Model, Msg, init, update, view, subscriptions)

import Debug exposing (..) 

main =
  Html.program
    { init = init, update = update, view = view, subscriptions = subscriptions }

-- MODEL

type alias Model =
    { 
      recording : Result String MidiRecording
    , player : Midi.Player.Model
    }

{-| initialise the model and delegate the initial command to that of the player -}
init : (Model, Cmd Msg)
init =
  let
    recording = Err "not started"
    (player, playerCmd) = Midi.Player.init recording
  in
    { 
      recording = recording
    , player = player
    } ! [Cmd.map PlayerMsg playerCmd]

-- UPDATE

type Msg
    = NoOp   
    | LoadMidi String                       -- request to load the MIDI file
    | Midi (Result String MidiRecording )   -- response that the MIDI file has been loaded
    | PlayerMsg Midi.Player.Msg             -- delegated messages for the player

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NoOp -> (model, Cmd.none )

    LoadMidi name ->
       (model, loadMidi name )

    Midi result -> 
       ( { model | recording = result }, establishRecording result ) 

    PlayerMsg playerMsg -> 
      let 
        (newPlayer, cmd) = Midi.Player.update playerMsg model.player
      in 
        { model | player = newPlayer } ! [Cmd.map PlayerMsg cmd]

 
-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model = 
  Sub.batch 
    [ Sub.map PlayerMsg (Midi.Player.subscriptions model.player)
    ]

      
-- EFFECTS

{- load a MIDI file -}
loadMidi : String -> Cmd Msg
loadMidi url = 
      let settings =  { defaultSettings | desiredResponseType  = Just "text/plain; charset=x-user-defined" }   
        in
          Http.send settings
                          { verb = "GET"
                          , headers = []
                          , url = url
                          , body = empty
                          } 
          |> Task.toResult
          |> Task.map extractResponse
          |> Task.map parseLoadedFile
          |> Task.perform (\_ -> NoOp) Midi 

establishRecording : Result String MidiRecording -> Cmd Msg
establishRecording r =
  Task.perform (\_ -> NoOp) 
               (\_ -> PlayerMsg (Midi.Player.SetRecording r)) 
               (Task.succeed (\_ -> ()))


{- extract the true response, concentrating on 200 statuses - assume other statuses are in error
   (usually 404 not found)
-}
extractResponse : Result RawError Response -> Result String Value
extractResponse result = case result of
    Ok response -> case response.status of
        200 -> Ok response.value
        _ -> Err (toString (response.status) ++ ": " ++ response.statusText)
    Err e -> Err "unexpected http error"

parseLoadedFile : Result String Value -> Result String MidiRecording
parseLoadedFile r = case r of
  Ok text -> case text of
    Http.Text s -> s |> normalise |> parse 
    Blob b -> Err "Blob unsupported"
  Err e -> Err e

-- VIEW

{- view the result - just for debug purposes -}
viewRecordingResult : Result String MidiTrack -> String
viewRecordingResult mr = 
   case mr of
      Ok res -> 
         "OK: " ++ (toString res)
      Err errs -> 
         "Fail: " ++ (toString errs)

view : Model -> Html Msg
view model =
  div [] 
    [  
      loadButton model
    {- , div [  ] [ text ("recording result: " ++ (viewRecordingResult model.track0)) ] - use for debug -}
    ,  Html.map PlayerMsg (Midi.Player.view model.player) 
    ]

{- the player capsule -}
loadButton : Model -> Html Msg
loadButton model = 
  case model.recording of
    Ok _ ->
      div [] []
    Err _ ->
      button 
        [ 
          onClick (LoadMidi "midi/lillasystern.midi")
          -- , style buttonStyle
        ] [ text "load file" ]    


-- CSS
buttonStyle : List (String, String)
buttonStyle = 
  [ ("margin", "0 auto")
  , ("width", "80px")
  , ("float", "right")
  , ("opacity", "0.7")
  ]


  







