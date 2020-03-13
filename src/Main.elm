module Main exposing (..)

import Browser as Browser exposing (element)
import Browser.Events exposing (Visibility(..))
import Html exposing (Html, div, text)
import Html.Attributes exposing (id, style)
import Html.Events exposing (onClick)
import Json.Decode as Decode
import List exposing (map)


default_velocity =
    3



-- Type Aliases ----------------------------------------------------------------


{-| when the mouse is moving, ,
the time left before it expires should pause
-}
type alias UIFlags =
    { display_help : Float -- ms left to display controls list
    , userClosedModal : Bool
    }


type alias Velocity =
    { x : Int
    , y : Int
    }


type alias Coordinate =
    { x : Int
    , y : Int
    }


type alias BrowserSize =
    { width : Int
    , height : Int
    }


type alias DVD =
    { width : Int
    , height : Int
    }


type alias Flag =
    { windowWidth : Int
    , windowHeight : Int
    , choices : List String
    , debug : Bool
    }



-- Event Helpers ----------------------------------------------------------------
-- Key Events


{-| the directions a user can move the the DVD logo
-}
type KeyDirection
    = K_Up
    | K_Left
    | K_Down
    | K_Right


{-| actions user can give using the keyboard
-}
type UserInputEvent
    = Movement KeyDirection
    | NoKey


{-| Handle decoding the X,Y position of the mouse on the page
-}
mouseDecoder : Decode.Decoder Coordinate
mouseDecoder =
    Decode.map2 Coordinate
        (Decode.field "pageX" Decode.int)
        (Decode.field "pageY" Decode.int)


keyDecoder : Decode.Decoder UserInputEvent
keyDecoder =
    Decode.map keyHandler (Decode.field "key" Decode.string)


keyHandler : String -> UserInputEvent
keyHandler inputStr =
    case String.uncons inputStr of
        Just ( char, "" ) ->
            case Char.toLower char of
                'w' ->
                    Movement K_Up

                'a' ->
                    Movement K_Left

                's' ->
                    Movement K_Down

                'd' ->
                    Movement K_Right

                _ ->
                    NoKey

        _ ->
            NoKey


{-| Return Boolean that describes whether or not animation is paused
-}
isPaused : Visibility -> Bool
isPaused vis =
    case vis of
        Visible ->
            True

        Hidden ->
            False


updateDVDSize : BrowserSize -> DVD
updateDVDSize browser =
    { width = browser.width // 5
    , height = browser.width // 10
    }



-- Model -----------------------------------------------------------------------


type alias Model =
    { location : Coordinate -- x, y location of the dvd div
    , ticks : Float -- ms passed since page load
    , velocity : Velocity -- x,y velocity of dvd
    , flags : UIFlags -- specifies whether the help message is being displayed
    , userInput : UserInputEvent -- user input event to consume
    , active : Visibility -- whether page is focused or not, pause game
    , browserSize : BrowserSize -- the current browser size (width, height)
    , choices : List String -- list of strings to select from for logo text
    , dvd : DVD -- the size of the dvd div itself
    , score : Int -- numbers of times the dvd has hit the corner
    , debug : Bool -- display the model as the page instead of the animation
    , mouseLocation : Coordinate
    }



-- Init ----------------------------------------------------------------------


initModel : Flag -> Model
initModel flags =
    let
        browserSize =
            { width = flags.windowWidth, height = flags.windowHeight }
    in
    { location = { x = browserSize.width // 5, y = browserSize.height // 5 }
    , ticks = 0.0
    , velocity = { x = default_velocity, y = default_velocity }
    , flags = { display_help = 10000, userClosedModal = False }
    , userInput = NoKey
    , active = Visible
    , browserSize = browserSize
    , choices = flags.choices
    , dvd = updateDVDSize browserSize
    , score = 0
    , debug = flags.debug
    , mouseLocation = { x = 0, y = 0 }
    }


init : Flag -> ( Model, Cmd Msg )
init flags =
    ( initModel flags
    , Cmd.none
    )



-- Update ----------------------------------------------------------------------


type Msg
    = Tick Float -- game tick
    | KeyUp UserInputEvent -- listen for key up events
    | VisibilityChanged Visibility -- pause animation on visibility false
    | UpdateBrowserSize Int Int -- browser size changed, update width/height
    | IncrementScore -- called from the updateVelocity function, to signify user hit the corner
    | MouseMove Coordinate -- listen for when the mouse moves
    | UserClosedHelp -- dont show help on mouse move if user clicks 'x'



-- methods to manage colliding with the edge of the screen
-- get x, y location for corners of the dvd div


type CornerType
    = TopLeft
    | TopRight
    | BottomLeft
    | BottomRight


getDVDCornerLocation : Model -> CornerType -> Coordinate
getDVDCornerLocation model corner =
    case corner of
        TopLeft ->
            { x = model.location.x
            , y = model.location.y
            }

        TopRight ->
            { x = model.location.x + model.dvd.width
            , y = model.location.y
            }

        BottomLeft ->
            { x = model.location.x
            , y = model.location.y + model.dvd.height
            }

        BottomRight ->
            { x = model.location.x + model.dvd.width
            , y = model.location.y + model.dvd.height
            }


{-| check if the div hit a corner or edge, update
velocity and score accordingly
-}
updateVelocity : Model -> Model
updateVelocity model =
    -- check corners and then edges
    let
        topLeftCoords =
            getDVDCornerLocation model TopLeft

        topRightCoords =
            getDVDCornerLocation model TopRight

        bottomLeftCoords =
            getDVDCornerLocation model BottomLeft

        bottomRightCoords =
            getDVDCornerLocation model BottomRight

        incrementScore : Model -> Model
        incrementScore mdl =
            let
                ( new_model, _ ) =
                    update IncrementScore mdl
            in
            new_model

        -- flip horizontal velocity
        flipVelocityHorizontal : Model -> Model
        flipVelocityHorizontal fh_model =
            let
                vel =
                    fh_model.velocity
            in
            { fh_model
                | velocity = { vel | x = -vel.x }
            }

        -- flip vertical velocity
        flipVelocityVertical : Model -> Model
        flipVelocityVertical fv_model =
            let
                vel =
                    model.velocity
            in
            { fv_model
                | velocity = { vel | y = -vel.y }
            }

        -- flip velocity for both directions (for corners)
        flipVelocityBoth : Model -> Model
        flipVelocityBoth fb_model =
            let
                vel =
                    fb_model.velocity
            in
            { fb_model
                | velocity =
                    { vel
                        | x = -vel.x
                        , y = -vel.y
                    }
            }
    in
    if
        -- flip both velocities
        (topLeftCoords.x <= 0 && topLeftCoords.y <= 0)
            || (topRightCoords.x >= model.browserSize.width && topRightCoords.y <= 0)
            || (bottomLeftCoords.x <= 0 && bottomLeftCoords.y >= model.browserSize.height)
            || (bottomRightCoords.x >= model.browserSize.width && bottomRightCoords.y >= model.browserSize.height)
    then
        model |> flipVelocityBoth |> incrementScore
        -- vertical flip velocity

    else if topLeftCoords.y <= 0 || bottomLeftCoords.y >= model.browserSize.height then
        model |> flipVelocityVertical
        -- horizontal flip velocity

    else if topLeftCoords.x <= 0 || topRightCoords.x >= model.browserSize.width then
        model |> flipVelocityHorizontal

    else
        model


{-| add the elapsed time (milliseconds) to the tick time
-}
incrementTick : Model -> Float -> Model
incrementTick model elapsed_ms =
    { model | ticks = model.ticks + elapsed_ms }


{-| updates the location based on the velocity
-}
updateLocation : Model -> Model
updateLocation model =
    { model
        | location =
            { x = model.location.x + model.velocity.x
            , y = model.location.y + model.velocity.y
            }
    }


{-| decay time to display the help message
-}
decayHelpTime : Float -> Model -> Model
decayHelpTime elapsed_ms model =
    if model.flags.display_help > 0 then
        let
            m_flags =
                model.flags
        in
        { model | flags = { m_flags | display_help = m_flags.display_help - elapsed_ms } }

    else
        model


{-| checks the location of the dvd logo based on browser size
changes velocity if applicable
updates the model and runs events on each render tick
-}
gameLoop : Model -> Float -> ( Model, Cmd Msg )
gameLoop model elapsed_ms =
    ( incrementTick model elapsed_ms
        |> decayHelpTime elapsed_ms
        |> updateVelocity
        |> updateLocation
    , Cmd.none
    )


{-| updates the model when a message is recieved
-}
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        -- handle IncrementScore
        increaseScoreHandler : Model -> Model
        increaseScoreHandler s_model =
            { s_model | score = s_model.score + 1 }

        -- handle UpdateBrowserSize
        updateOnBrowserResize : Model -> Int -> Int -> Model
        updateOnBrowserResize u_model new_width new_height =
            let
                browserSize =
                    { width = new_width, height = new_height }
            in
            { u_model
                | location = { x = browserSize.width // 5, y = browserSize.height // 5 }
                , velocity = { x = default_velocity, y = default_velocity }
                , dvd = updateDVDSize browserSize
                , browserSize = browserSize
            }

        -- When the user moves the mouse, set the help text to display for a minimum of 5 seconds
        handleMouseMove : Model -> Model
        handleMouseMove h_model =
            if h_model.flags.display_help >= 5000 then
                h_model

            else
                let
                    m_flags =
                        h_model.flags
                in
                { h_model | flags = { m_flags | display_help = 5000 } }
    in
    case msg of
        Tick elapsed_ms ->
            gameLoop model elapsed_ms

        KeyUp key ->
            ( { model | userInput = key }
            , Cmd.none
            )

        VisibilityChanged vis ->
            ( { model | active = vis }
            , Cmd.none
            )

        UpdateBrowserSize new_width new_height ->
            ( updateOnBrowserResize model new_width new_height
            , Cmd.none
            )

        IncrementScore ->
            ( increaseScoreHandler model
            , Cmd.none
            )

        MouseMove _ ->
            -- ignore the coordinate, just capture the mousemove event
            ( model |> handleMouseMove
            , Cmd.none
            )

        UserClosedHelp ->
            let
                ui_flags =
                    model.flags
            in
            ( { model | flags = { ui_flags | userClosedModal = True } }
            , Cmd.none
            )



-- Subscriptions ---------------------------------------------------------------


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch <|
        [ Browser.Events.onKeyUp (Decode.map KeyUp keyDecoder) -- get keyup events
        , Browser.Events.onVisibilityChange VisibilityChanged -- get visibility change events
        , Browser.Events.onResize (\w h -> UpdateBrowserSize w h)
        , Browser.Events.onMouseMove (Decode.map MouseMove mouseDecoder)
        ]
            ++ (if isPaused model.active then
                    -- get a Tick event based on browser render tick rate
                    -- (requestAnimationFrame js func)
                    [ Browser.Events.onAnimationFrameDelta Tick ]

                else
                    []
               )



-- View ------------------------------------------------------------------------


pixel : Int -> String
pixel pixelInt =
    String.fromInt pixelInt ++ "px"


renderHelp : Model -> Html Msg
renderHelp model =
    let
        -- create a list of basic divs from a list of strings
        div_list : List String -> List (Html Msg)
        div_list div_contents =
            map (\ds -> div [] [ text ds ]) div_contents
    in
    if not model.flags.userClosedModal && model.flags.display_help > 0 then
        div
            [ id "help" ]
            ([ div
                [ id "close-button"
                , onClick UserClosedHelp ]
                [ text "×" ]
             ]
                ++ div_list [ "one", "two", "three" ]
            )

    else
        div [] []


debugInfo : Model -> Html Msg
debugInfo model =
    if model.debug then
        div [ id "debug" ] [ text (Debug.toString model) ]

    else
        div [] []


renderDVD : Model -> Html Msg
renderDVD model =
    div
        [ style "width" (pixel model.dvd.width)
        , style "height" (pixel model.dvd.height)
        , style "left" (pixel model.location.x)
        , style "top" (pixel model.location.y)
        , id "dvd"
        ]
        [ text (String.fromInt model.score) ]


view : Model -> Html Msg
view model =
    div
        [ id "tv-screen"
        ]
        [ renderHelp model
        , renderDVD model
        , debugInfo model
        ]


main : Program Flag Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
