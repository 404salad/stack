module Main exposing (main)

import Browser
import Html exposing (Html, button, div, h2, input, li, text, ul)
import Html.Attributes exposing (checked, style, type_)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode exposing (Decoder)


-- BASE URL

baseUrl : String
baseUrl =
    "http://localhost:8080"


-- MODEL

type alias Collection =
    { id : Int
    , name : String
    }

type alias Book =
    { bookId : Int
    , name : String
    , position : Int
    , read : Bool
    , collectionId : Int
    }

type alias Model =
    { collections : List Collection
    , books : List Book
    , error : Maybe String
    }

initialModel : Model
initialModel =
    { collections = []
    , books = []
    , error = Nothing
    }


-- MESSAGES

type Msg
    = FetchCollections
    | FetchCollectionsResponse (Result Http.Error (List Collection))
    | FetchBooks Int
    | FetchBooksResponse (Result Http.Error (List Book))
    | ToggleRead Int Int
    | ToggleReadResponse (Result Http.Error Book)


-- INIT

init : () -> ( Model, Cmd Msg )
init _ =
    ( initialModel, getCollections )


-- UPDATE

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FetchCollections ->
            ( model, getCollections )

        FetchCollectionsResponse (Ok cols) ->
            ( { model | collections = cols }, Cmd.none )

        FetchCollectionsResponse (Err _) ->
            ( { model | error = Just "Failed to load collections" }, Cmd.none )

        FetchBooks cid ->
            ( model, getBooks cid )

        FetchBooksResponse (Ok newBooks) ->
            -- Add to existing books, avoiding duplicates by bookId
            let
                existingIds = List.map .bookId model.books
                filtered = List.filter (\b -> not (List.member b.bookId existingIds)) newBooks
            in
            ( { model | books = model.books ++ filtered }, Cmd.none )

        FetchBooksResponse (Err _) ->
            ( { model | error = Just "Failed to load books" }, Cmd.none )

        ToggleRead collectionId bookId ->
            ( model, toggleReadCmd collectionId bookId )

        ToggleReadResponse (Ok updatedBook) ->
            let
                updatedList =
                    List.map (\b -> if b.bookId == updatedBook.bookId then updatedBook else b) model.books
            in
            ( { model | books = updatedList }, Cmd.none )

        ToggleReadResponse (Err _) ->
            ( { model | error = Just "Failed to toggle read status" }, Cmd.none )


-- VIEW

view : Model -> Html Msg
view model =
    div [ style "font-family" "sans-serif", style "padding" "20px" ]
        [ h2 [] [ text "📚 Books recommended by your friends" ]
        , case model.collections of
            [] ->
                text "Loading collections..."

            cols ->
                div []
                    (List.map (viewCollectionWithStack model) cols)
        , case model.error of
            Nothing ->
                text ""

            Just e ->
                div [ style "color" "red", style "margin-top" "10px" ] [ text e ]
        ]


viewCollectionWithStack : Model -> Collection -> Html Msg
viewCollectionWithStack model col =
    let
        booksInCollection =
            List.filter (\b -> b.collectionId == col.id) model.books
    in
    div [ style "margin-bottom" "30px" ]
        [ h2 [] [ text col.name ]
        , button [ onClick (FetchBooks col.id) ] [ text "Fetch/Add books" ]
        , div
            [ style "position" "relative"
            , style "height" (String.fromInt (List.length booksInCollection * 40) ++ "px")
            , style "width" "220px"
            , style "margin-top" "20px"
            ]
            (List.indexedMap
                (\index book ->
                    viewStackedBook index book
                )
                booksInCollection
            )
        ]


viewStackedBook : Int -> Book -> Html Msg
viewStackedBook index book =
    div
        [ style "position" "absolute"
        , style "top" (String.fromInt (index * 40) ++ "px")
        , style "left" (String.fromInt (index * 10) ++ "px")
        , style "width" "200px"
        , style "height" "30px"
        , style "background-color" "#ddd"
        , style "border" "1px solid #aaa"
        , style "border-radius" "4px"
        , style "padding" "5px"
        ]
        [ input [ type_ "checkbox", checked book.read, onClick (ToggleRead book.collectionId book.bookId) ] []
        , div [ style "margin-left" "8px" ] [ text book.name ]
        ]


-- HTTP

collectionDecoder : Decoder Collection
collectionDecoder =
    Decode.map2 Collection
        (Decode.field "id" Decode.int)
        (Decode.field "name" Decode.string)

collectionsDecoder : Decoder (List Collection)
collectionsDecoder =
    Decode.list collectionDecoder

bookDecoder : Decoder Book
bookDecoder =
    Decode.map5 Book
        (Decode.field "book_id" Decode.int)
        (Decode.field "name" Decode.string)
        (Decode.field "position" Decode.int)
        (Decode.field "done" Decode.bool)          -- backend field is still "done"
        (Decode.field "collection_id" Decode.int)

booksDecoder : Decoder (List Book)
booksDecoder =
    Decode.list bookDecoder

getCollections : Cmd Msg
getCollections =
    Http.get
        { url = baseUrl ++ "/collections"
        , expect = Http.expectJson FetchCollectionsResponse collectionsDecoder
        }

getBooks : Int -> Cmd Msg
getBooks cid =
    Http.get
        { url = baseUrl ++ "/collections/" ++ String.fromInt cid ++ "/books"
        , expect = Http.expectJson FetchBooksResponse booksDecoder
        }

toggleReadCmd :Int -> Int -> Cmd Msg
toggleReadCmd collectionId bookId =
    Http.request
        { method = "PATCH"
        , headers = []
        , url = baseUrl ++ "/collections/" ++ String.fromInt collectionId ++ "/books/" ++ String.fromInt bookId ++ "/toggle"
        , body = Http.emptyBody
        , expect = Http.expectJson ToggleReadResponse bookDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


-- MAIN

main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }

