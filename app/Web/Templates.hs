{-# LANGUAGE OverloadedStrings #-}

module Web.Templates where

import qualified Control.Monad as Monad
import qualified Data.List as List
import qualified Data.Maybe as Maybe
import qualified Data.Ord as Ord
import qualified Data.Text as T
import qualified Data.Time as Time
import qualified Data.Time.Clock.POSIX as POSIXTime
import qualified Data.Time.Format as DateTimeFormat
import qualified Data.Word as Word
import qualified System.IO.Unsafe as Unsafe
import qualified Text.Printf as Text

import qualified Text.Blaze.Html5 as H
import qualified Text.Blaze.Html5.Attributes as A
import qualified Text.Blaze.Internal as I

import Types
import Web.Styles
import Web.Types
import Utils.Time
import Utils.Config

-- | Navigation Components

navBar :: [NavLink] -> H.Html
navBar links = H.div H.! A.class_ "nav-bar" $ do
  let separator = H.span H.! A.class_ "nav-separator" $ "///"
      withSeparators [] = return ()
      withSeparators [x] = navLink x
      withSeparators (x:xs) = H.div H.! A.class_ "nav-bar-row" $ do
        navLink x
        separator
        withSeparators xs
      navLink link =
        if linkActive link
          then H.span H.! A.class_ "nav-link active" $
            H.toHtml $ linkText link
          else H.a H.! A.class_ "nav-link"
               H.! A.href (H.textValue $ linkPath link) $
            H.toHtml $ linkText link
  withSeparators links

-- | Core Templates

rootTemplate :: Int -> [Aorb] -> H.Html  -- Add Int parameter for user count
rootTemplate userCount' aorbs = H.docTypeHtml $ H.html $ do
  H.head $ do
    H.link H.! A.rel "icon" H.! A.href "data:,"
    H.meta H.! A.name "viewport" H.!
        A.content "width=device-width, initial-scale=1.0"
    H.title "anorby"
    H.style $ H.text rootPageCSS
  H.body $ do
    H.span H.! A.id "top" $ ""
    H.div H.! A.class_ "frame" $ do
      navBar [ NavLink "/" "home" True
             , NavLink "/whoami" "whoami" False
             , NavLink "/ans" "answer" False
             , NavLink "/match" "match" False
             ]
      H.h1 $ do
        H.span H.! A.class_ "underline" $ "a"
        H.text "n"
        H.span H.! A.class_ "underline" $ "or"
        H.span H.! A.class_ "underline" $ "b"
        H.text "y"
      H.div $ do
        H.a H.! A.href "#baseline" $ "the underground census"
    H.span H.! A.id "baseline" $ ""
    H.div H.! A.class_ "frame" $ do
      H.h1 "baseline_100"
      H.h4 "what is this... blah blah blah"
      H.a H.! A.href "/roadmap" $ do
        H.h4 $ H.text $ T.pack $ "# of responses: " ++ show userCount'
      H.div H.! A.id "sorter" $ do
        H.div H.! A.class_ "sort-by" $ "sort by:"
        H.a H.! A.class_ "sort-by" H.! A.href "#by-sided" $ "> most one-sided"
        H.a H.! A.class_ "sort-by" H.! A.href "#by-polar" $ "> most polarizing"
        H.a H.! A.class_ "sort-by" H.! A.href "#by-dice" $ "> random"
    H.span H.! A.id "aorbs" $ ""
    H.div H.! A.class_ "frame" H.! A.style "padding-top: 10vh;" $ do
      H.div H.! A.id "by-sided" $ mempty
      H.div H.! A.id "by-dice" $ mempty
      H.div H.! A.id "by-polar" $ mempty
      H.span H.! A.class_ "notch" $ do
        H.a H.! A.href "#baseline" $ "backtobasebasebase"
      publicAorbs aorbs

roadmapTemplate :: Int -> H.Html
roadmapTemplate userCount' = H.docTypeHtml $ H.html $ do
  H.head $ do
    H.link H.! A.rel "icon" H.! A.href "data:,"
    H.meta H.! A.name "viewport" H.!
        A.content "width=device-width, initial-scale=1.0"
    H.title "roadmap"
    H.style $ H.text $ combineCSS [baseCSS, navBarCSS, roadmapCSS]
  H.body $ do
    H.span H.! A.id "top" $ ""
    H.div H.! A.class_ "frame" $ do
      navBar [ NavLink "/#baseline" "back" False ]
      H.h1 "roadmap"
      H.div $ do
        H.a H.! A.href "#milestone-100" $ "begin"
    milestoneFrame
      "100" userCount' "#milestone-500" False
      (Just "weekly matching begins")
    milestoneFrame
      "500" userCount' "#milestone-1000" False
      (Just "weekly new questions")
    milestoneFrame
      "1000" userCount' "#milestone-5000" False
      (Just "daily matching begins")
    milestoneFrame
      "5000" userCount' "#top" True
      (Just "daily new questions")

milestoneFrame :: T.Text -> Int -> T.Text -> Bool -> Maybe T.Text -> H.Html
milestoneFrame threshold userCount' nextLink bottom maybeProgressText = do
  let users = read (T.unpack threshold) :: Int
      progress :: Int
      progress = min 100 $ round ((fromIntegral userCount' /
                                 fromIntegral users) * 100 :: Double)
      progressClass = if userCount' >= users
                     then "milestone-complete"
                     else "milestone-incomplete"
      progressText = case maybeProgressText of
        Just txt -> txt
        Nothing -> threshold
  H.span H.! A.id (H.textValue $ "milestone-" <> threshold) $ ""
  H.div H.! A.class_ "frame" $ do
    H.h2 $ do
      H.text $ threshold <> " users"
    H.div H.! A.class_ progressClass $ do
      H.div H.! A.class_ "progress-bar" H.!
        A.style (H.textValue $ "width: " <> T.pack (show progress) <> "%") $ ""
      H.div H.! A.class_ "milestone-marker" $ H.text progressText
    H.div H.! A.class_ "next-milestone" $ do
      H.a H.! A.href (H.textValue nextLink) $
        (if bottom then "top" else  "next")

publicAorbs :: [Aorb] -> H.Html
publicAorbs aorbs = do
  H.div H.! A.id "aorbs-container" $ do
    Monad.forM_ (aorbWithOrders aorbs) $
      \(_, (aorb, orders)) -> do
        H.div H.! A.class_ "aorb" H.!
          A.style (aorbDynamicCSS (zip ["dice", "polar", "sided"] orders)) $ do
            H.div H.! A.class_ "context" $ H.toHtml (aorbCtx aorb)
            let mean = aorbMean aorb
                delta = (abs (mean - 0.5)) * 100
                formatDelta =
                    T.concat ["(+", T.pack (Text.printf "%.2f" delta), ")"]
            if delta < 0.01
              then do
                H.div H.! A.class_ "choice" $ do
                  H.toHtml (aorbA aorb)
                  H.span H.! A.class_ "neutral" $ H.toHtml $ T.pack " ...?"
                H.div H.! A.class_ "choice" $ do
                  H.toHtml (aorbB aorb)
                  H.span H.! A.class_ "neutral" $ H.toHtml $ T.pack " ...?"
              else if mean > 0.5
              then do
                H.div H.! A.class_ "choice preferred" $ do
                  H.toHtml (aorbB aorb)
                  H.span H.! A.class_ "delta" $ H.toHtml formatDelta
                H.div H.! A.class_ "choice alternative" $
                  H.toHtml (aorbA aorb)
              else do
                H.div H.! A.class_ "choice preferred" $ do
                  H.toHtml (aorbA aorb)
                  H.span H.! A.class_ "delta" $ H.toHtml formatDelta
                H.div H.! A.class_ "choice alternative" $
                  H.toHtml (aorbB aorb)

profileTemplate :: [AorbWithAnswer] -> Maybe AorbID
                -> Maybe T.Text -> Maybe T.Text
                -> H.Html
profileTemplate aorbs mAid maybeUuid shareUrl =
  H.docTypeHtml $ H.html $ do
    profileHead maybeUuid
    H.body $ do
      profileHeadline maybeUuid $ H.div $ do
        H.a H.! A.href "#main" $ "begin"
      profileFullView mAid aorbs maybeUuid shareUrl

profileHead :: Maybe T.Text -> H.Html
profileHead maybeUuid = H.head $ do
  H.title $ case maybeUuid of
    Just uuid -> H.text $ "share/" <> uuid
    Nothing -> "whoami"
  H.link H.! A.rel "icon" H.! A.href "data:,"
  H.meta H.! A.name "viewport" H.!
    A.content "width=device-width, initial-scale=1.0"
  H.style $ I.preEscapedText $ profilePageCSS maybeUuid

profileHeadline :: Maybe T.Text -> H.Html -> H.Html
profileHeadline maybeUuid children = do
  H.span H.! A.id "top" $ ""
  H.div H.! A.class_ "frame" $ do
    navBar [ NavLink "/" "home" False
           , NavLink "/whoami" "whoami"
              (case maybeUuid of Just _ -> False ; _ -> True)
           , NavLink "/ans" "answer" False
           , NavLink "/match" "match" False
           ]
    H.h1 $ case maybeUuid of
      Just uuid -> H.text $ "#" <> uuid
      Nothing -> "whoami"
    children

profileMainAorb :: Maybe AorbID -> [AorbWithAnswer] -> Maybe T.Text -> H.Html
profileMainAorb mAid aorbs maybeUuid =
  case (mAid, maybeUuid) of
    (Just aid, Just _) -> do
      H.span H.! A.id "main" $ ""
      H.div H.! A.class_ "frame" $ do
        H.h1 "main"
        H.div H.! A.class_ "aorbs-container" $ do
          mapM_ (\awa -> profileAorb awa mAid Nothing maybeUuid) $
            filter (\awa -> aorbId (aorbData awa) == aid) aorbs
    (Nothing, Just _) -> mempty
    (Just aid, Nothing) -> do
      H.span H.! A.id "main" $ ""
      H.div H.! A.class_ "frame" $ do
        H.h1 "main"
        H.div H.! A.class_ "aorbs-container" $ do
          mapM_ (\awa -> profileAorb awa mAid Nothing maybeUuid) $
            filter (\awa -> aorbId (aorbData awa) == aid) aorbs
    (Nothing, Nothing) -> do
      H.span H.! A.id "main" $ ""
      H.div H.! A.class_ "frame" $ do
        H.h1 "main"
        H.div H.! A.class_ "no-main-instructions" $ do
          H.p "you haven't selected your main question yet"
          H.p "pick from the answers below"

profileCommonplaceAorbs :: Maybe AorbID -> [AorbWithAnswer] -> Maybe T.Text
                       -> H.Html
profileCommonplaceAorbs mAid aorbs maybeUuid =
  H.div H.! A.class_ "frame" $ do
    H.h1 "most commonplace"
    H.div H.! A.class_ "aorbs-container" $ do
      mapM_
        (\awa -> profileAorb awa mAid Nothing maybeUuid)
        (take 3 $ reverse aorbs)

profileControversialAorbs :: Maybe AorbID -> [AorbWithAnswer] -> Maybe T.Text
                         -> H.Html
profileControversialAorbs mAid aorbs maybeUuid =
  H.div H.! A.class_ "frame" $ do
    H.h1 "most controversial"
    H.div H.! A.class_ "aorbs-container" $ do
      mapM_
        (\awa -> profileAorb awa mAid Nothing maybeUuid)
        (take 3 aorbs)

profileAllAnswers :: Maybe AorbID -> [AorbWithAnswer] -> Maybe T.Text -> H.Html
profileAllAnswers mAid aorbs maybeUuid = do
  H.span H.! A.id "all-answers" $ ""
  H.div H.! A.class_ "frame" $ do
    H.h1 "all answers"
    H.div H.! A.id "sorter" $ do
      H.div H.! A.class_ "sort-by" $ "sort by:"
      H.a H.! A.class_ "sort-by" H.!
        A.href "#by-flake" $ "> most controversial"
      H.a H.! A.class_ "sort-by" H.!
        A.href "#by-basic" $ "> most commonplace"
  H.div H.! A.class_ "frame" H.! A.style "padding-top: 10vh" $ do
    H.div H.! A.id "by-basic" $ mempty
    H.div H.! A.id "by-flake" $ mempty
    H.span H.! A.class_ "notch" $ do
      H.a H.! A.href "#all-answers" $ "backtoallanswersss"
    profileOrdinaryAorbs mAid aorbs maybeUuid

profileSharer :: Maybe T.Text -> Maybe T.Text -> H.Html
profileSharer maybeUuid shareUrl = case (maybeUuid, shareUrl) of
  (Nothing, Just url) -> H.div H.! A.class_ "frame" $ do
    H.h1 "share"
    H.div $ H.text url
  _ -> mempty

accountManager :: Maybe T.Text -> H.Html
accountManager maybeUuid =
  case maybeUuid of
    Nothing ->
      H.div H.! A.class_ "frame" $ do
        H.div $ do H.a H.! A.href "/account" $ "manage my account"
    _ -> mempty

profileFullView :: Maybe AorbID -> [AorbWithAnswer]
                -> Maybe T.Text -> Maybe T.Text
                -> H.Html
profileFullView mAid aorbs maybeUuid shareUrl = do
  profileMainAorb mAid aorbs maybeUuid
  Monad.when (Maybe.isNothing mAid) $ H.span H.! A.id "main" $ ""
  profileCommonplaceAorbs mAid aorbs maybeUuid
  profileControversialAorbs mAid aorbs maybeUuid
  profileAllAnswers mAid aorbs maybeUuid
  profileSharer maybeUuid shareUrl
  accountManager maybeUuid

profileAorb :: AorbWithAnswer -> Maybe AorbID -> Maybe [Int] -> Maybe T.Text
            -> H.Html
profileAorb awa mFavoriteId mOrders maybeUuid = do
  let aorb = aorbData awa
      ans = userAnswer awa
      aid = aorbId aorb
      isFavorite = maybe False (== aid) mFavoriteId
      percentage =
        case ans of
          AorbAnswer 0 -> 100 * (1 - aorbMean aorb)
          _ -> 100 * aorbMean aorb
      favoriteClass = if isFavorite then " aorb-favorite" else ""
      dynamicStyle = case mOrders of
        Just orders ->
          (H.! A.style (aorbDynamicCSS (zip ["basic", "flake"] orders)))
        Nothing -> id
      baseWrapper contents = case maybeUuid of
        Just _ ->
          H.div H.! A.class_ "aorb-clickable" $ contents
        Nothing ->
          H.a H.! A.href (H.toValue $ "/ans/" ++ show aid)
              H.! A.class_ "aorb-clickable" $ contents
  dynamicStyle $ baseWrapper $ do
    H.div H.! A.class_ (H.textValue $ "aorb" <> favoriteClass) $ do
      H.div H.! A.class_ "context" $ H.toHtml $ aorbCtx aorb
      H.div H.! A.class_ (if ans == AorbAnswer 0
                          then "choice selected"
                          else "choice") $ do
        H.toHtml $ aorbA aorb
        Monad.when (ans == AorbAnswer 0) $
          H.span H.! A.class_ "percentage" $
            H.toHtml $ T.pack $ Text.printf " /\\/ %.0f%%" percentage
      H.div H.! A.class_ (if ans == AorbAnswer 1
                          then "choice selected"
                          else "choice") $ do
        H.toHtml $ aorbB aorb
        Monad.when (ans == AorbAnswer 1) $
          H.span H.! A.class_ "percentage" $
            H.toHtml $ T.pack $ Text.printf " /\\/ %.0f%%" percentage

profileOrdinaryAorbs :: Maybe AorbID -> [AorbWithAnswer] -> Maybe T.Text
                     -> H.Html
profileOrdinaryAorbs mAid aorbs maybeUuid = do
  H.div H.! A.id "aorbs-container" $ do
    Monad.forM_ (aorbWithAnswerWithOrders aorbs) $
      \(_, (awa, orders)) -> profileAorb awa mAid (Just orders) maybeUuid

aorbsWithOrders :: (Eq a) => [a] -> [OrderingFunction a] -> [(Int, (a, [Int]))]
aorbsWithOrders as orderingFuncs = zip [(1::Int)..] $
  let orderedLists = map (\f -> f as) orderingFuncs
      lookupOrder list a = maybe 0 (+1) $ List.elemIndex a list
  in [ (a, map (\orderedList -> lookupOrder orderedList a) orderedLists)
     | a <- as ]

aorbWithOrders :: [Aorb] -> [(Int, (Aorb, [Int]))]
aorbWithOrders as = aorbsWithOrders as aorbOrderings

aorbWithAnswerWithOrders :: [AorbWithAnswer]
                         -> [(Int, (AorbWithAnswer, [Int]))]
aorbWithAnswerWithOrders awas = aorbsWithOrders awas aorbWithAnswerOrderings

aorbOrderings :: [OrderingFunction Aorb]
aorbOrderings =
  [ id                                                     -- byDice
  , List.sortOn (\a -> abs (aorbMean a - 0.5))             -- byPolar
  , List.sortOn (Ord.Down . \a -> abs (aorbMean a - 0.5))  -- bySided
  ]

aorbWithAnswerOrderings :: [OrderingFunction AorbWithAnswer]
aorbWithAnswerOrderings =
  [ reverse   -- byBasic
  , id        -- byFlake
  ]

ansTemplate :: Aorb -> Bool -> T.Text -> H.Html
ansTemplate aorb shouldSwap token = H.docTypeHtml $ H.html $ do
  H.head $ do
    H.title "answer"
    H.link H.! A.rel "icon" H.! A.href "data:,"
    H.meta H.! A.name "viewport" H.!
      A.content "width=device-width, initial-scale=1.0"
    H.style $ I.preEscapedText ansPageCSS
  H.body $ do
    H.div H.! A.class_ "frame" $ do
      navBar [ NavLink "/" "home" False
             , NavLink "/whoami" "whoami" False
             , NavLink "/ans" "answer" True
             , NavLink "/match" "match" False
             ]
      H.div H.! A.class_ "ans-context" $
        H.toHtml (aorbCtx aorb)
      H.div H.! A.class_ "ans-choices" $
        let (firstChoice, firstValue, secondChoice, secondValue) =
              if shouldSwap
                then (aorbB aorb, 1, aorbA aorb, 0)
                else (aorbA aorb, 0, aorbB aorb, 1)
        in do
          makeChoice aorb token firstChoice firstValue
          makeChoice aorb token secondChoice secondValue
  where
    makeChoice :: Aorb -> T.Text -> T.Text -> Word.Word8 -> H.Html
    makeChoice a t choice value = do
      H.form H.! A.method "POST" H.! A.action "/ans/submit" $ do
        H.input H.! A.type_ "hidden" H.!
          A.name "aorb_id" H.!
          A.value (H.toValue $ show $ aorbId a)
        H.input H.! A.type_ "hidden" H.!
          A.name "token" H.!
          A.value (H.textValue t)
        H.input H.! A.type_ "hidden" H.!
          A.name "choice" H.!
          A.value (H.toValue $ show value)
        H.button H.!
          A.type_ "submit" H.!
          A.class_ "ans-choice" $
          H.toHtml choice

existingAnswerTemplate :: Aorb -> Maybe AorbAnswer -> Bool -> T.Text -> H.Html
existingAnswerTemplate aorb mCurrentAnswer isFavorite token =
  H.docTypeHtml $ H.html $ do
  H.head $ do
    H.title "answer"
    H.link H.! A.rel "icon" H.! A.href "data:,"
    H.meta H.! A.name "viewport" H.!
      A.content "width=device-width, initial-scale=1.0"
    H.style $ I.preEscapedText $ combineCSS
      [ baseCSS
      , navBarCSS
      , ansComponentsCSS
      , clickableAorbCSS
      ]
  H.body $ do
    H.div H.! A.class_ "frame" $ do
      navBar [ NavLink "/" "home" False
             , NavLink "/whoami" "whoami" False
             , NavLink "/ans" "answer" True
             , NavLink "/match" "match" False
             ]
      H.div H.! A.class_ "ans-context" $
        H.toHtml (aorbCtx aorb)
      H.div H.! A.class_ "ans-choices" $ do
        makeExistingChoice aorb token (aorbA aorb) 0
          (mCurrentAnswer == Just (AorbAnswer 0)) isFavorite
        makeExistingChoice aorb token (aorbB aorb) 1
          (mCurrentAnswer == Just (AorbAnswer 1)) isFavorite
      if isFavorite
        then mempty
        else
          H.div H.! A.class_ "favorite-section" $ do
            H.form H.! A.method "POST"
                   H.! A.action
                     (H.toValue $ "/aorb/favorite/" ++ show (aorbId aorb)) $ do
              H.button
                H.! A.type_ "submit"
                H.! A.class_ (H.textValue $ "favorite-button active") $
                  "set as favorite question"
  where
    makeExistingChoice ::
      Aorb -> T.Text -> T.Text -> Word.Word8 -> Bool -> Bool -> H.Html
    makeExistingChoice a t choice value isSelected favorite = do
      H.form H.! A.method "POST" H.! A.action "/ans/edit" $ do
        H.input H.! A.type_ "hidden" H.!
          A.name "aorb_id" H.!
          A.value (H.toValue $ show $ aorbId a)
        H.input H.! A.type_ "hidden" H.!
          A.name "token" H.!
          A.value (H.textValue t)
        H.input H.! A.type_ "hidden" H.!
          A.name "choice" H.!
          A.value (H.toValue $ show value)
        H.button H.!
          A.type_ "submit" H.!
          A.class_ (H.textValue $ "ans-choice" <>
                    if isSelected
                    then " selected" <> if favorite then " favorite" else ""
                    else "") $
          H.toHtml choice

matchTemplate :: Config -> POSIXTime.POSIXTime
              -> Maybe POSIXTime.POSIXTime -> Maybe POSIXTime.POSIXTime
              -> Int -> Int -> Int -> Maybe (Match, Double) -> H.Html
matchTemplate
  config now maybeCutoffTime maybeReleaseTime
  answerCount totalQuestions enrolledCount maybeMatchScore =
  H.docTypeHtml $ H.html $ do
  H.head $ do
    H.link H.! A.rel "icon" H.! A.href "data:,"
    H.meta H.! A.name "viewport" H.!
        A.content "width=device-width, initial-scale=1.0"
    H.title "match"
    H.style $ H.text matchPageCSS
  H.body $ do
    H.span H.! A.id "top" $ ""
    H.div H.! A.class_ "frame" $ do
      navBar [ NavLink "/" "home" False
             , NavLink "/whoami" "whoami" False
             , NavLink "/ans" "answer" False
             , NavLink "/match" "match" True
             ]
      H.h1 "match"
      H.div H.! A.class_ "secondary-nav" $ do
        H.a H.! A.href "/match/found" $ "past"
        H.span H.! A.class_ "nav-divider" $ "|"
        H.a H.! A.href "#today" $ "present"
        H.span H.! A.class_ "nav-divider" $ "|"
        H.a H.! A.href "/match/type" $ "future"
    H.span H.! A.id "today" $ ""
    H.div H.! A.class_ "frame" $ do
      H.h1 "today"
      matchTodaySection
        config
        now
        maybeCutoffTime
        maybeReleaseTime
        answerCount
        totalQuestions
        enrolledCount
        maybeMatchScore

matchTodaySection :: Config -> POSIXTime.POSIXTime
                  -> Maybe POSIXTime.POSIXTime -> Maybe POSIXTime.POSIXTime
                  -> Int -> Int -> Int -> Maybe (Match, Double) -> H.Html
matchTodaySection config now maybeCutoffTime maybeReleaseTime
  answerCount totalQs enrolled maybeMatchScore =
  let remainingToday = 10 - answerCount
      hasAnsweredAll = answerCount >= totalQs
      isEnrolled = hasAnsweredAll || answerCount >= 10
      otherUsersCount = max 0 (enrolled - 1)
      enrolledText =
        if otherUsersCount == 1
        then "1 other user enrolled"
        else T.pack (show otherUsersCount) <> " other users enrolled"
      isBeforeCutoff = case maybeCutoffTime of
        Just ct -> now < ct
        Nothing -> True
      isBeforeRelease = case maybeReleaseTime of
        Just rt -> now < rt
        Nothing -> True
      timeUntilCutoff = case maybeCutoffTime of
        Just ct -> formatTimeUntil now ct
        Nothing -> "soon"
      timeUntilRelease = case maybeReleaseTime of
        Just rt -> formatTimeUntil now rt
        Nothing -> "soon"

  in H.div H.! A.class_ "today-status" $ do
      Monad.when isBeforeRelease $
        H.div H.! A.class_ "status-box count-status" $
          H.text enrolledText

      Monad.when isBeforeRelease $
        H.div H.! A.class_ (if isEnrolled
                            then "status-box enrolled-status"
                            else "status-box pending-status") $ do
          if isBeforeCutoff
            then if isEnrolled
              then H.text "you are enrolled for today's matching"
              else do
                H.text $ T.pack $
                  "answer " <> show remainingToday <>
                  " more questions to join today's matching pool"
                H.br
                H.a H.! A.href "/ans" $ "answer more questions"
            else if isEnrolled
              then H.text "you are enrolled for today's matching"
              else H.text "missed today's matching cutoff"

      Monad.when isBeforeRelease $
        H.div H.! A.class_ "status-box time-status" $ do
          let displayTime = if isBeforeCutoff && not isEnrolled
                            then (timeUntilCutoff, matchCutoffTime config)
                            else (timeUntilRelease, matchReleaseTime config)
          case displayTime of
            (timeLeft, timeStr) -> do
              if isBeforeCutoff || isEnrolled
                then do
                  H.span H.! A.class_ "time-until" $
                    if isEnrolled
                      then H.text $ "matches released in " <> timeLeft
                      else H.text $ "cutoff in " <> timeLeft
                  H.span H.! A.class_ "exact-time" $
                    H.text $ " (" <> timeStr <> " UTC)"
                else
                  H.text "answer your questions before tomorrow's cutoff"

      Monad.unless isBeforeRelease $
        case maybeMatchScore of
          Just matchScore -> matchCard (fst matchScore) (snd matchScore)
          Nothing -> H.div H.! A.class_ "status-box pending-status" $
            H.text "no match found for today"

matchTypeTemplate :: User -> H.Html
matchTypeTemplate user = H.docTypeHtml $ H.html $ do
  H.head $ do
    H.title "match type"
    H.link H.! A.rel "icon" H.! A.href "data:,"
    H.meta H.! A.name "viewport" H.!
      A.content "width=device-width, initial-scale=1.0"
    H.style $ H.text matchPageCSS
  H.body $ do
    H.div H.! A.class_ "frame" $ do
      navBar [ NavLink "/match" "back" False ]
      H.h1 "match type"

      H.div H.! A.class_ "scheme-grid" $ do
        schemeCard PPPod (userAssoc user)
        schemeCard Fencer (userAssoc user)
        schemeCard Bipolar (userAssoc user)

      H.div $ do H.a H.! A.href "#explained" $ "explain"

    H.span H.! A.id "explained" $ ""
    H.div H.! A.class_ "frame" $ do
      H.div H.! A.class_ "description-frame" $ do
        H.h2 "how it works"
        H.p "each type determines how you'll be matched with other users:"
        schemeDetailedDescription PPPod
        schemeDetailedDescription Fencer
        schemeDetailedDescription Bipolar

schemeCard :: AssociationScheme -> Maybe AssociationScheme -> H.Html
schemeCard scheme currentScheme =
  let isSelected = currentScheme == Just scheme
      cardClass = "scheme-card" <> if isSelected then " selected" else ""
      schemeName = show scheme
  in H.form H.! A.method "POST" H.! A.action "/match/type" $ do
    H.button
      H.! A.type_ "submit"
      H.! A.name "assoc"
      H.! A.value (H.toValue schemeName)
      H.! A.class_ (H.textValue cardClass) $ do
        H.div
          H.! A.class_ (H.textValue $ "scheme-name " <> T.pack schemeName) $
          H.toHtml schemeName

schemeDetailedDescription :: AssociationScheme -> H.Html
schemeDetailedDescription scheme =
  H.div H.! A.style "margin: 2rem 0" $ do
    H.h3 H.! A.style (H.textValue $ fontFamily scheme) $
      H.toHtml $ schemeName scheme
    H.p $ H.toHtml $ schemeDetail scheme
  where
    fontFamily :: AssociationScheme -> T.Text
    fontFamily PPPod = "font-family: 'Times New Roman', serif"
    fontFamily Fencer = "font-family: 'Courier New', monospace"
    fontFamily Bipolar = "font-family: 'Arial Black', sans-serif"

    schemeName :: AssociationScheme -> T.Text
    schemeName PPPod = "PPPod"
    schemeName Fencer = "Fencer"
    schemeName Bipolar = "Bipolar"

    schemeDetail :: AssociationScheme -> T.Text
    schemeDetail PPPod = T.unlines
      [ "..." ]

    schemeDetail Fencer = T.unlines
      [ "..." ]

    schemeDetail Bipolar = T.unlines
      [ "..." ]

matchFoundTemplate :: [(Match, Double)] -> H.Html
matchFoundTemplate matchScores = H.docTypeHtml $ H.html $ do
  H.head $ do
    H.title "matches"
    H.link H.! A.rel "icon" H.! A.href "data:,"
    H.meta H.! A.name "viewport" H.!
      A.content "width=device-width, initial-scale=1.0"
    H.style $ H.text $ combineCSS
      [baseCSS, navBarCSS, matchFoundCSS, matchCardCSS]
  H.body $ do
    H.div H.! A.class_ "frame" $ do
      navBar [ NavLink "/match" "back" False ]
      H.h1 "matches"
      if null matchScores
        then H.div H.! A.class_ "no-matches" $ do
          H.p "no matches found"
        else do
          H.h4 "(agreement rate)"
          H.div H.! A.class_ "match-grid" $ do
            mapM_ (\(m, s) -> matchCard m s) $ take 7 matchScores

matchCard :: Match -> Double -> H.Html
matchCard match score =
  H.a H.! A.class_ "match-card"
    H.! A.href (H.textValue $ "/match/found/t-" <>
                formatMatchDelta (matchTimestamp match)) $ do
    H.div H.! A.class_ "match-date" $
      H.toHtml $ formatMatchDate (matchTimestamp match)
    H.div H.! A.class_ "match-score" $
      H.toHtml $ formatSimilarityScore score
  where
    formatSimilarityScore :: Double -> T.Text
    formatSimilarityScore s =
      T.pack $ Text.printf "%.0f%%" ((s + 1) * 50)
    formatDate :: POSIXTime.POSIXTime -> T.Text
    formatDate timestamp = T.pack $
      DateTimeFormat.formatTime
      DateTimeFormat.defaultTimeLocale
      "%Y-%m-%d"
      (POSIXTime.posixSecondsToUTCTime timestamp)
    formatMatchDelta :: POSIXTime.POSIXTime -> T.Text
    formatMatchDelta timestamp = T.pack $ show $ Unsafe.unsafePerformIO $ do
      now <- Time.getCurrentTime
      let posixTime = POSIXTime.posixSecondsToUTCTime timestamp
          diffDays = Time.diffUTCTime now posixTime
      return $ (floor (diffDays / Time.nominalDay) :: Integer)
    formatMatchDate :: POSIXTime.POSIXTime -> T.Text
    formatMatchDate timestamp = do
      let matchDay = formatDate timestamp
          today = formatDate (Unsafe.unsafePerformIO POSIXTime.getPOSIXTime)
          yesterday = formatDate (Unsafe.unsafePerformIO $
            fmap (\now -> now - 24 * 60 * 60) POSIXTime.getPOSIXTime)
      case () of
        _ | matchDay == today -> "today"
          | matchDay == yesterday -> "yesterday"
          | otherwise -> matchDay

-- | Auth Templates

loginTemplate :: T.Text -> H.Html
loginTemplate token = H.docTypeHtml $ H.html $ do
  H.head $ do
    H.title "login"
    H.link H.! A.rel "icon" H.! A.href "data:,"
    H.meta H.! A.name "viewport" H.!
      A.content "width=device-width, initial-scale=1.0"
    H.style $ H.text authPageCSS
  H.body $ do
    H.div H.! A.class_ "frame" $ do
      navBar [ NavLink "/" "home" False
             , NavLink "/login" "login" True
             , NavLink "/register" "register" False
             ]
      H.div H.! A.class_ "auth-form" $ do
        H.form H.! A.class_ "auth-form"
          H.! A.method "POST" H.! A.action "/login" $ do
          H.input H.! A.type_ "email"
                 H.! A.name "email"
                 H.! A.placeholder "email"
                 H.! A.class_ "auth-input"
                 H.! A.required "required"
          H.input H.! A.type_ "hidden"
                 H.! A.name "token"
                 H.! A.value (H.textValue token)
          H.button H.! A.type_ "submit"
                  H.! A.class_ "auth-button" $ "login"

registerTemplate :: T.Text -> H.Html
registerTemplate token = H.docTypeHtml $ H.html $ do
  H.head $ do
    H.title "register"
    H.link H.! A.rel "icon" H.! A.href "data:,"
    H.meta H.! A.name "viewport" H.!
      A.content "width=device-width, initial-scale=1.0"
    H.style $ H.text authPageCSS
  H.body $ do
    H.div H.! A.class_ "frame" $ do
      navBar [ NavLink "/" "home" False
             , NavLink "/login" "login" False
             , NavLink "/register" "register" True
             ]
      H.div H.! A.class_ "auth-form" $ do
        H.form H.! A.class_ "auth-form"
          H.! A.method "POST" H.! A.action "/register" $ do
          H.input H.! A.type_ "email"
                 H.! A.name "email"
                 H.! A.placeholder "email"
                 H.! A.class_ "auth-input"
                 H.! A.required "required"
          H.input H.! A.type_ "hidden"
                 H.! A.name "token"
                 H.! A.value (H.textValue token)
          H.button H.! A.type_ "submit"
                  H.! A.class_ "auth-button" $ "register"

accountTemplate :: User -> H.Html
accountTemplate user = H.docTypeHtml $ H.html $ do
  H.head $ do
    H.title "account"
    H.link H.! A.rel "icon" H.! A.href "data:,"
    H.meta H.! A.name "viewport" H.!
      A.content "width=device-width, initial-scale=1.0"
    H.style $ I.preEscapedText accountPageCSS
  H.body $ do
    H.div H.! A.class_ "frame" $ do
      navBar [ NavLink "/" "home" False
             , NavLink "/whoami" "whoami" False
             , NavLink "/ans" "answer" False
             , NavLink "/match" "match" False
             ]
      H.div H.! A.class_ "account-section" $ do
        H.h2 H.! A.class_ "account-heading" $ "account information"
        H.p $ do
          H.text "Email: "
          H.toHtml $ userEmail user

        H.div H.! A.class_ "danger-zone" $ do
          H.h3 H.! A.class_ "danger-heading" $ "danger zone"
          H.p $ do
            H.text "logout from all devices: "
            H.a H.! A.href "/logout" $ "confirm via email"
          H.p $ do
            H.text "delete account and all data: "
            H.a H.! A.href "/delete" $ "confirm via email"

confirmTemplate :: T.Text -> T.Text -> T.Text -> T.Text -> T.Text -> T.Text
                -> H.Html
confirmTemplate title warning action token actionText cancelUrl =
  H.docTypeHtml $ H.html $ do
    H.head $ do
      H.title $ H.toHtml title
      H.link H.! A.rel "icon" H.! A.href "data:,"
      H.meta H.! A.name "viewport" H.!
        A.content "width=device-width, initial-scale=1.0"
      H.style $ I.preEscapedText accountPageCSS
    H.body $ do
      H.div H.! A.class_ "frame" $ do
        H.form H.! A.method "POST" H.! A.action (H.textValue action) $ do
          H.input H.! A.type_ "hidden"
                 H.! A.name "token"
                 H.! A.value (H.textValue token)
          H.button H.! A.type_ "submit" H.! A.class_ "confirm-button" $
            H.toHtml actionText
        H.h1 $ H.toHtml title
        H.p $ H.toHtml warning
        H.a H.! A.href (H.textValue cancelUrl) H.! A.class_ "cancel-button" $
          "cancel"

-- | Message Templates

msgTemplate :: MessageTemplate -> H.Html
msgTemplate template = H.docTypeHtml $ H.html $ do
  H.head $ do
    H.title $ H.toHtml $ messageTitle template
    H.link H.! A.rel "icon" H.! A.href "data:,"
    H.meta H.! A.name "viewport" H.!
      A.content "width=device-width, initial-scale=1.0"
    H.style $ I.preEscapedText baseCSS
  H.body $ do
    H.div H.! A.class_ "frame" $ do
      H.h1 $ H.toHtml $ messageHeading template
      H.div $ do
        H.a H.! A.href (H.textValue $ fst $ messageLink template) $
          H.toHtml $ snd $ messageLink template

emailSentTemplate :: H.Html
emailSentTemplate = msgTemplate MessageTemplate
  { messageTitle = "check your email"
  , messageHeading = "check your email"
  , messageLink = ("/", "home")
  }

dailyLimitTemplate :: T.Text -> H.Html
dailyLimitTemplate timeLeft = msgTemplate MessageTemplate
  { messageTitle = "daily limit"
  , messageHeading = "daily answer limit reached, come back in " <> timeLeft
  , messageLink = ("/whoami", "back to profile")
  }

noMoreQuestionsTemplate :: H.Html
noMoreQuestionsTemplate = msgTemplate MessageTemplate
  { messageTitle = "no more questions"
  , messageHeading = "no more questions"
  , messageLink = ("/whoami", "back to profile")
  }

profileNotYetActive :: Int -> H.Html
profileNotYetActive threshold = msgTemplate MessageTemplate
  { messageTitle = "profile not yet active"
  , messageHeading = T.pack $
      "your profile will be activated after answering "
      ++ show threshold ++ " questions"
  , messageLink = ("/ans", "answer more questions")
  }
matchNotYetActive :: Int -> H.Html
matchNotYetActive threshold = msgTemplate MessageTemplate
  { messageTitle = "match not yet active"
  , messageHeading = T.pack $
      "matching will be activated after answering "
      ++ show threshold ++ " questions"
  , messageLink = ("/ans", "answer more questions")
  }

errorTemplateWithLink :: Int -> T.Text -> (T.Text, T.Text) -> H.Html
errorTemplateWithLink code message link = msgTemplate MessageTemplate
  { messageTitle = message
  , messageHeading = T.pack (show code) <> " - " <> message
  , messageLink = link
  }

errorTemplate :: Int -> T.Text -> H.Html
errorTemplate code message =
  errorTemplateWithLink code message ("/", "go home")

alreadyAnsweredTemplate :: H.Html
alreadyAnsweredTemplate = errorTemplateWithLink
  403 "question already answered" ("/ans", "next question")

invalidTokenTemplate :: H.Html
invalidTokenTemplate = errorTemplateWithLink
  403 "invalid or expired token" ("/ans", "try again")

invalidSubmissionTemplate :: H.Html
invalidSubmissionTemplate = errorTemplateWithLink
  400 "invalid submission format" ("/ans", "try again")

userNotFoundTemplate :: H.Html
userNotFoundTemplate =
  errorTemplateWithLink 404 "user not found" ("/register", "register")

emailExistsTemplate :: H.Html
emailExistsTemplate =
  errorTemplateWithLink 409 "email already registered" ("/login", "login")

notFoundTemplate :: H.Html
notFoundTemplate = errorTemplate 404 "not found"

internalErrorTemplate :: H.Html
internalErrorTemplate = errorTemplate 500 "internal server error"
