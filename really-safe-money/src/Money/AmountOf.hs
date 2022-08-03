{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -Wno-duplicate-exports -Wno-dodgy-exports #-}

module Money.AmountOf
  ( AmountOf (..),
    zero,
    fromAmount,
    toAmount,
    toMinimalQuantisations,
    fromMinimalQuantisations,
    fromDouble,
    toDouble,
    fromRational,
    toRational,
    Currency (..),
    add,
    Amount.AdditionFailure (..),
    subtract,
    Amount.SubtractionFailure (..),
    multiply,
    Amount.MultiplicationFailure (..),
    divide,
    Amount.DivisionFailure (..),
    fraction,
    Amount.FractionFailure (..),
  )
where

import Control.DeepSeq
import Data.Int
import Data.Proxy
import Data.Typeable
import Data.Validity
import Data.Word
import GHC.Generics (Generic)
import GHC.TypeLits
import Money.Amount (Amount)
import qualified Money.Amount as Amount
import Money.Currency as Currency
import Prelude hiding (fromRational, subtract, toRational)

-- | An amount of money of a specific currency. May be negative.
--
-- === Representation
--
-- The underlying representation is 'Amount'.
-- See its documentation for more details.
newtype AmountOf currency = AmountOf
  { unAmountOf :: Amount
  }
  deriving (Show, Read, Eq, Ord, Typeable, Generic)

instance Validity (AmountOf currency)

instance NFData (AmountOf currency)

instance
  TypeError
    ( 'Text "This would require that Amounts of money are an instance of Enum"
        ':$$: 'Text "Amounts of money must not be an instance of Enum. Don't do this."
        ':$$: 'Text "In particular:"
        ':$$: 'Text "* succ and pred would be partial."
        ':$$: 'Text "* the fromEnum :: Amount -> Int function would be partial on 32-bit systems."
    ) =>
  Enum (AmountOf currency)
  where
  toEnum = undefined
  fromEnum = undefined

instance
  TypeError
    ( 'Text "This would require that Amounts of money are an instance of Bounded"
        ':$$: 'Text "Amounts of money must not be an instance of Bounded. Don't do this."
        ':$$: 'Text "The reasoning is more philosophical than practical:"
        ':$$: 'Text "It is not clear which bound to choose."
        ':$$: 'Text "Setting the bounds equal to the bounds of the representation is surprising if there is a clear bound on the amount of a currency, like in the case of BTC."
        ':$$: 'Text "Setting the bounds equal to the bounds of currency is only possible if there is a clear bound, like in the case of BTC, and that the instance exists at all would be surprising in the case of USD."
    ) =>
  Bounded (AmountOf currency)
  where
  minBound = undefined
  maxBound = undefined

instance
  TypeError
    ( 'Text "This would require that Amounts of money are an instance of Num"
        ':$$: 'Text "Amounts of money must not be an instance of Num. Don't do this."
        ':$$: 'Text "In particular:"
        ':$$: 'Text "* (*) cannot be implemented because the units don't match."
        ':$$: 'Text "* abs would be wrong for minBound."
        ':$$: 'Text "* negate would be wrong for minBound."
    ) =>
  Num (AmountOf currency)
  where
  (+) = undefined
  (*) = undefined
  abs = undefined
  signum = undefined
  fromInteger = undefined
  negate = undefined
  (-) = undefined

zero :: AmountOf currency
zero = AmountOf Amount.zero

fromAmount :: Amount -> AmountOf currency
fromAmount = AmountOf

toAmount :: AmountOf currency -> Amount
toAmount = unAmountOf

toMinimalQuantisations :: AmountOf currency -> Int64
toMinimalQuantisations = Amount.toMinimalQuantisations . toAmount

fromMinimalQuantisations :: Int64 -> AmountOf currency
fromMinimalQuantisations = fromAmount . Amount.fromMinimalQuantisations

fromDouble :: forall currency. Currency currency => Double -> Maybe (AmountOf currency)
fromDouble = fmap AmountOf . Amount.fromDouble (quantisationFactor (Proxy @currency))

toDouble :: forall currency. Currency currency => AmountOf currency -> Double
toDouble = Amount.toDouble (quantisationFactor (Proxy @currency)) . unAmountOf

fromRational :: forall currency. Currency currency => Rational -> Maybe (AmountOf currency)
fromRational = fmap AmountOf . Amount.fromRational (quantisationFactor (Proxy @currency))

toRational :: forall currency. Currency currency => AmountOf currency -> Rational
toRational = Amount.toRational (quantisationFactor (Proxy @currency)) . unAmountOf

-- | Add two amounts of money.
--
-- This operation may fail with an 'AdditionFailure' for the following reasons:
--
-- TODO
add :: AmountOf currency -> AmountOf currency -> Either Amount.AdditionFailure (AmountOf currency)
add (AmountOf a1) (AmountOf a2) = AmountOf <$> Amount.add a1 a2

subtract :: AmountOf currency -> AmountOf currency -> Either Amount.SubtractionFailure (AmountOf currency)
subtract (AmountOf a1) (AmountOf a2) = AmountOf <$> Amount.subtract a1 a2

-- API Note: The order of arguments in 'multiply' and 'divide' is reversed to increase the likelyhood of a compile-error when refactoring.
multiply ::
  Int32 ->
  AmountOf currency ->
  Either Amount.MultiplicationFailure (AmountOf currency)
multiply f (AmountOf a) = AmountOf <$> Amount.multiply f a

-- API Note: The order of arguments in 'multiply' and 'divide' is reversed to increase the likelyhood of a compile-error when refactoring.
divide ::
  AmountOf currency ->
  Word32 ->
  Either Amount.DivisionFailure (AmountOf currency)
divide (AmountOf a) i = AmountOf <$> Amount.divide a i

fraction ::
  AmountOf currency ->
  Rational ->
  (AmountOf currency, Rational)
fraction (AmountOf a) f =
  let (a', r) = Amount.fraction a f
   in (AmountOf a', r)
