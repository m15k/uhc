let  data Bit        = Zero | One
     data List a     = Nil | Cons a (List a)
     data GRose f a  = GBranch a (f (GRose f a))
     concat :: List a -> List a -> List a
in   let  class Binary a where
            showBin :: a -> List Bit
in   let  instance Binary Int where
            showBin  = ...
          instance Binary a => Binary (List a) where
            showBin  = ...
          instance (Binary a, (forall b . Binary b => Binary (f b)))
                          => Binary (GRose f a) where
            showBin  =  \(GBranch x ts)
                          -> concat (showBin x) (showBin ts)
in   let  v1 = showBin (GBranch 3 Nil)
     in   v1
