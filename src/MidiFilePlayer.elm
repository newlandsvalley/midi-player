module MidiFilePlayer exposing (..)

{-
   Proof of concept of a MIDI audio player using an embedded MIDI player module

   This allows buttons of start/pause/continue/reset

   in order to contol the playing of the MIDI file
   (again played by means of soundfonts and Web-Audio through elm ports)

-}

import Html exposing (Html, div, button, input, text, progress)
import Html.Events exposing (onClick, on, onInput, targetValue)
import Html.Attributes exposing (src, type_, style, value, max, accept, id)
import Http exposing (..)
import Task exposing (..)
import String exposing (..)
import Result exposing (Result)
import Json.Decode as Json exposing (succeed)
import CoMidi exposing (normalise, parse, translateRunningStatus)
import MidiTypes exposing (MidiEvent(..), MidiRecording)
import Midi.Track exposing (..)
import Midi.Player exposing (Model, Msg, init, update, view, subscriptions)
import BinaryFileIO.Ports exposing (..)
import Debug exposing (..)


main =
    Html.program
        { init = init, update = update, view = view, subscriptions = subscriptions }



-- MODEL


type alias Model =
    { recording : Result String MidiRecording
    , player : Midi.Player.Model
    }


{-| initialise the model and delegate the initial command to that of the player
-}
init : ( Model, Cmd Msg )
init =
    let
        recording =
            Err "not started"

        ( player, playerCmd ) =
            Midi.Player.init recording
    in
        { recording = recording
        , player = player
        }
            ! [ Cmd.map PlayerMsg playerCmd ]



-- UPDATE


type Msg
    = NoOp
    | LoadMidi String
      -- request to load the MIDI file
    | RequestFileUpload
    | FileLoaded (Maybe Filespec)
    | MidiBinaryString (Result Error String)
      -- the raw MIDI binary
    | Midi (Result String MidiRecording)
      -- response that the MIDI file has been loaded
    | PlayerMsg Midi.Player.Msg



-- delegated messages for the player


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        LoadMidi name ->
            ( model, loadMidi name )

        RequestFileUpload ->
            ( model, requestLoadFile () )

        FileLoaded maybef ->
            case maybef of
                Just f ->
                    let
                        recording =
                            normalise f.contents
                                |> parse
                                |> translateRunningStatus
                    in
                        ( { model
                            | recording = recording
                          }
                        , establishRecording recording
                        )

                Nothing ->
                    ( model, Cmd.none )

        MidiBinaryString result ->
            update (Midi (parseLoadedFile result)) model

        Midi result ->
            ( { model | recording = result }, establishRecording result )

        PlayerMsg playerMsg ->
            let
                ( newPlayer, cmd ) =
                    Midi.Player.update playerMsg model.player
            in
                { model | player = newPlayer } ! [ Cmd.map PlayerMsg cmd ]



-- SUBSCRIPTIONS


fileLoadedSub : Sub Msg
fileLoadedSub =
    fileLoaded FileLoaded


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Sub.map PlayerMsg (Midi.Player.subscriptions model.player)
        , fileLoadedSub
        ]



-- EFFECTS
{- load a MIDI file -}


loadMidi : String -> Cmd Msg
loadMidi url =
    let
        accept =
            Http.header "Accept" "text/plain; charset=x-user-defined"

        contentType =
            Http.header "Content-Type" "text/plain; charset=x-user-defined"

        rquest : Request String
        rquest =
            request
                { method = "Get"
                , headers =
                    [ accept, contentType ]
                    --, headers = []
                , url = url
                , body = emptyBody
                , expect = expectString
                , timeout = Nothing
                , withCredentials = False
                }
    in
        Http.send MidiBinaryString rquest


establishRecording : Result String MidiRecording -> Cmd Msg
establishRecording r =
    Task.perform (\_ -> PlayerMsg (Midi.Player.SetRecording r))
        (Task.succeed (\_ -> ()))


parseLoadedFile : Result Error String -> Result String MidiRecording
parseLoadedFile s =
    case s of
        Ok text ->
            text |> normalise |> parse

        Err e ->
            Err (toString e)



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
        [ loadButtons model {- , div [  ] [ text ("recording result: " ++ (viewRecordingResult model.track0)) ] - use for debug -}
        , Html.map PlayerMsg (Midi.Player.view model.player)
        ]



{- load the midi files if not yet loaded -}


loadButtons : Model -> Html Msg
loadButtons model =
    case model.recording of
        Ok _ ->
            div [] []

        Err _ ->
            div []
                [ input
                    [ type_ "file"
                    , id "fileinput"
                    , accept ".midi"
                    , on "change" (Json.succeed RequestFileUpload)
                    ]
                    []
                ]



{- [ button
       [ onClick (LoadMidi "midi/lillasystern.midi")
         -- , style buttonStyle
       ]
       [ text "load file" ]
   , button
       [ onClick (LoadMidi "midi/chordsample.midi")
         -- , style buttonStyle
       ]
       [ text "load chord sample" ]
   ]
-}
-- CSS


buttonStyle : List ( String, String )
buttonStyle =
    [ ( "margin", "0 auto" )
    , ( "width", "80px" )
    , ( "float", "right" )
    , ( "opacity", "0.7" )
    ]
