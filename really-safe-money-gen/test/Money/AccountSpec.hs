{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module Money.AccountSpec (spec) where

import Data.GenValidity.Vector ()
import Money.Account (Account (..))
import qualified Money.Account as Account
import Money.Account.Gen ()
import Money.Amount (Amount (..))
import qualified Money.Amount as Amount
import Test.QuickCheck hiding (Negative (..), Positive (..))
import Test.Syd
import Test.Syd.Validity

spec :: Spec
spec = modifyMaxSuccess (* 100) . modifyMaxSize (* 3) $ do
  describe "Eq" $ do
    it "says negative 0 equals positive 0" $
      Positive Amount.zero == Negative Amount.zero
    eqSpec @Account

  describe "Ord" $ do
    it "says 4 is smaller than 5" $
      Positive (Amount 4) < Positive (Amount 5)
    it "says -3 is smaller than 2" $
      Negative (Amount 3) < Positive (Amount 2)
    it "says -6 is greater than -7" $
      Negative (Amount 6) > Negative (Amount 7)
    ordSpec @Account

  showReadSpec @Account

  describe "toMinimalQuantisations" $
    it "produces valid accounts" $
      producesValid Account.toMinimalQuantisations

  describe "fromMinimalQuantisations" $ do
    it "produces valid accounts" $
      producesValid Account.fromMinimalQuantisations

    it "roundtrips with toMinimalQuantisations" $
      forAllValid $ \account ->
        Account.fromMinimalQuantisations (Account.toMinimalQuantisations account) `shouldBe` Just account

  describe "toRational" $ do
    it "produces valid Rationals when the quantisation factor is nonzero" $
      forAll (genValid `suchThat` (/= 0)) $ \quantisationFactor ->
        producesValid (Account.toRational quantisationFactor)

    it "produces an invalid Rational with quantisation factor 0" $
      forAllValid $ \a ->
        shouldBeInvalid $ Account.toRational 0 a

  describe "fromRational" $ do
    it "produces valid rational" $
      producesValid2 Account.fromRational

    it "roundtrips with toRational" $
      forAllValid $ \quantisationFactor ->
        forAllValid $ \account ->
          case Account.fromRational quantisationFactor (Account.toRational quantisationFactor account) of
            Nothing -> pure () -- Fine
            Just account' -> account' `shouldBe` account

  describe "toDouble" $ do
    it "produces valid Doubles when the quantisation factor is nonzero" $
      forAll (genValid `suchThat` (/= 0)) $ \quantisationFactor ->
        producesValid (Account.toDouble quantisationFactor)

    it "produces an infinite or NaN Double with quantisation factor 0" $
      forAllValid $ \a ->
        Account.toDouble 0 a `shouldSatisfy` (\d -> isInfinite d || isNaN d)

  describe "fromDouble" $ do
    it "produces valid rational" $
      producesValid2 Account.fromDouble

    xdescribe "does not hold" $
      it "roundtrips with toDouble" $
        forAllValid $ \quantisationFactor ->
          forAllValid $ \account ->
            case Account.fromDouble quantisationFactor (Account.toDouble quantisationFactor account) of
              Nothing -> pure () -- Fine
              Just account' -> account' `shouldBe` account

  describe "add" $ do
    it "fails for maxBound + 1" $
      Account.add (Positive (Amount maxBound)) (Positive (Amount 1))
        `shouldBe` Nothing

    it "fails for maxBound + maxBound" $
      Account.add (Positive (Amount maxBound)) (Positive (Amount maxBound))
        `shouldBe` Nothing

    it "fails for minBound + (-1)" $
      Account.add (Negative (Amount maxBound)) (Negative (Amount 1))
        `shouldBe` Nothing

    it "fails for minBound + minBound" $
      Account.add (Negative (Amount maxBound)) (Negative (Amount maxBound))
        `shouldBe` Nothing

    it "produces valid amounts" $
      producesValid2 Account.add

    it "has a left-identity: zero" $
      forAllValid $ \a ->
        Account.add Account.zero a `shouldBe` Just a

    it "has a right-identity: zero" $
      forAllValid $ \a ->
        Account.add a Account.zero `shouldBe` Just a

    it "is associative when both succeed" $
      forAllValid $ \a1 ->
        forAllValid $ \a2 ->
          forAllValid $ \a3 -> do
            let errOrL = Account.add <$> Account.add a1 a2 <*> pure a3
            let errOrR = Account.add <$> pure a1 <*> Account.add a2 a3
            case (,) <$> errOrL <*> errOrR of
              Nothing -> pure () -- Fine.
              Just (l, r) -> l `shouldBe` r

    it "is commutative" $
      forAllValid $ \a1 ->
        forAllValid $ \a2 ->
          Account.add a1 a2 `shouldBe` Account.add a2 a1

    it "matches what you would get with Integer, if nothing fails" $
      forAllValid $ \a1 ->
        forAllValid $ \a2 -> do
          let errOrAccount = Account.add a1 a2
          case errOrAccount of
            Nothing -> pure () -- Fine.
            Just amountResult -> do
              let integerResult =
                    Account.toMinimalQuantisations a1
                      + Account.toMinimalQuantisations a2
              Account.toMinimalQuantisations amountResult
                `shouldBe` integerResult

  describe "abs" $ do
    it "produces valid amounts" $
      producesValid Account.abs