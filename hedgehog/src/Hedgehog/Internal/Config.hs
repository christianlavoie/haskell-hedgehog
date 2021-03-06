{-# OPTIONS_HADDOCK not-home #-}
{-# LANGUAGE DoAndIfThenElse #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
module Hedgehog.Internal.Config (
    UseColor(..)
  , Verbosity(..)
  , WorkerCount(..)

  , detectMark
  , detectColor
  , detectVerbosity
  , detectWorkers
  ) where

import           Control.Monad.IO.Class (MonadIO(..))

import qualified GHC.Conc as Conc

import           Language.Haskell.TH.Lift (deriveLift)

import           System.Console.ANSI (hSupportsANSI)
import           System.Environment (lookupEnv)
import           System.IO (stdout)

import           Text.Read (readMaybe)


-- | Whether to render output using ANSI colors or not.
--
data UseColor =
    DisableColor
    -- ^ Disable ANSI colors in report output.
  | EnableColor
    -- ^ Enable ANSI colors in report output.
    deriving (Eq, Ord, Show)

-- | How verbose should the report output be.
--
data Verbosity =
    Quiet
    -- ^ Only display the summary of the test run.
  | Normal
    -- ^ Display each property as it is running, as well as the summary.
    deriving (Eq, Ord, Show)

-- | The number of workers to use when running properties in parallel.
--
newtype WorkerCount =
  WorkerCount Int
  deriving (Eq, Ord, Show, Num, Enum, Real, Integral)

detectMark :: MonadIO m => m Bool
detectMark = do
  user <- liftIO $ lookupEnv "USER"
  pure $ user == Just "mth"

lookupBool :: MonadIO m => String -> m (Maybe Bool)
lookupBool key =
  liftIO $ do
    menv <- lookupEnv key
    case menv of
      Just "0" ->
        pure $ Just False
      Just "no" ->
        pure $ Just False
      Just "false" ->
        pure $ Just False

      Just "1" ->
        pure $ Just True
      Just "yes" ->
        pure $ Just True
      Just "true" ->
        pure $ Just True

      _ ->
        pure Nothing

detectColor :: MonadIO m => m UseColor
detectColor =
  liftIO $ do
    ok <- lookupBool "HEDGEHOG_COLOR"
    case ok of
      Just False ->
        pure DisableColor

      Just True ->
        pure EnableColor

      Nothing -> do
        mth <- detectMark
        if mth then
          pure DisableColor -- avoid getting fired :)
        else do
          enable <- hSupportsANSI stdout
          if enable then
            pure EnableColor
          else
            pure DisableColor

detectVerbosity :: MonadIO m => m Verbosity
detectVerbosity =
  liftIO $ do
    menv <- (readMaybe =<<) <$> lookupEnv "HEDGEHOG_VERBOSITY"
    case menv of
      Just (0 :: Int) ->
        pure Quiet

      Just (1 :: Int) ->
        pure Normal

      _ -> do
        mth <- detectMark
        if mth then
          pure Quiet
        else
          pure Normal

detectWorkers :: MonadIO m => m WorkerCount
detectWorkers = do
  liftIO $ do
    menv <- (readMaybe =<<) <$> lookupEnv "HEDGEHOG_WORKERS"
    case menv of
      Nothing ->
        WorkerCount <$> Conc.getNumProcessors
      Just env ->
        pure $ WorkerCount env

------------------------------------------------------------------------
-- FIXME Replace with DeriveLift when we drop 7.10 support.

$(deriveLift ''UseColor)
$(deriveLift ''Verbosity)
$(deriveLift ''WorkerCount)
