midi-player
===========

This is an elm 0.17 module that encapsulates a control for the playback of single-track MIDI recordings which conform to the [MidiRecording](https://github.com/newlandsvalley/elm-comidi/blob/master/src/MidiTypes.elm) format (i.e. those produced by the elm-comidi parser).  The control uses stop, start and pause buttons and includes a capsule that indicates the proportion of the tune that has been played. It uses as an instrument the acoustic grand piano.

It exposes the following message type which sends a recording to the player:
    
    SetRecording (Result String MidiRecording)
    
Other messages which control the buttons are autonomous and invisibe to the caller. If the recording is single track, it is played as is; if multitrack, it plays track zero.    

## Integrating the module

The player is implemented using ports.  As such, it is not possible to produce a single build artefact that contains the complete module.  The module exposes the following:

    Model, Msg (LoadFonts, SetRecording), init, update, view, subscriptions 
    
This can be imported into a main elm program using the normal conventions.  The player will only become visible once the instructions to load the sound fonts and to set the recording have been issued to it.

### The calling program

The following section describes how a calling program that (somehow) gets hold of a MIDI recording via the MIDI message might integrate the player:

#### import

    import Midi.Player exposing (Model, Msg, init, update, view, subscriptions)
    
#### model

    type alias Model =
    { 
      myStuff :....
    , recording : Result String MidiRecording
    , player : Midi.Player.Model
    }
    
#### messages

    type Msg
      = MyMessage MyStuff
      | Midi (Result String MidiRecording )  
      | PlayerMsg Midi.Player.Msg             -- delegated messages for the player
    
#### initialisation

It is important that the calling program allows the player to be initialised:

    init : (Model, Cmd Msg)
    init =
      let
        myStuff = ....
        (player, playerCmd) = Midi.Player.init recording
      in
        { 
          myStuff = myStuff 
        , recording = Err "not started"
        , player = player
        } ! [Cmd.map PlayerMsg playerCmd]

#### update

    update : Msg -> Model -> (Model, Cmd Msg)
    update msg model =
      case msg of
      
        MyMessage stuff -> ...
                   
        Midi result -> 
          ( { model | recording = result }, establishRecording result )    

        PlayerMsg playerMsg -> 
          let 
            (newPlayer, cmd) = Midi.Player.update playerMsg model.player
          in 
            { model | player = newPlayer } ! [Cmd.map PlayerMsg cmd]
            
where _establishRecording_ sends a command to the player which establishes the recording to play:

    establishRecording : Result String MidiRecording -> Cmd Msg
    establishRecording r =
      Task.perform (\_ -> NoOp) 
                   (\_ -> PlayerMsg (Midi.Player.SetRecording r)) 
                   (Task.succeed (\_ -> ()))
                   
#### view

    view : Model -> Html Msg
    view model =
      div [] 
        [  
        myView ..
        ,  Html.map PlayerMsg (Midi.Player.view model.player) 
        ]
        
#### subscriptions

    subscriptions : Model -> Sub Msg
    subscriptions model = 
      Sub.batch 
        [  mySubs ...
        ,  Sub.map PlayerMsg (Midi.Player.subscriptions model.player)
        ]
        
### the html

The following components are required by the player:

* The javascript for the cobined calling program and player
* The javascript for the sound fonts called by the player through elm ports
* The soundfonts used by the player, assumed to be in the directory _assets/soundfonts_
* The image files used by the player widget assumed to be in the directory _assets/images_

The various pieces of javascript can be assmebled (here for a calling program named _MidiFilePlayer_) in the html file as follows

    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Elm 0.17 Midi Player module sample</title>

      </head>
      <body>
        <div id="elmMidiFilePlayer"></div>
        <script src="js/soundfont-player.js"></script>
        <script src="distjs/elmMidiFilePlayer.js"></script>
        <script>
          var node = document.getElementById('elmMidiFilePlayer');
          var myapp = Elm.MidiFilePlayer.embed(node);
        <!-- the javascript below is written to accept an initial parameter named node-->
        </script>
        <script src="js/nativeSoundFont.js"></script>
      </body>
    </html>