%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% PP configuration and varieties
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

1. Tailoring PP implementations

For PP of
- HsName
- HsName used as a constructor name
- Variable of some sort
- UID

and configuring
- whether to follow an underlying AST structure

2. Different uses of PP

As class variations on PP

%%[8 hs module {%{EH}Base.CfgPP}
%%]

%%[8 import({%{EH}Base.Common},{%{EH}Base.HsName},{%{EH}Base.Builtin},{%{EH}Scanner.Common})
%%]

%%[8 import(Data.Char)
%%]

%%[8 import(EH.Util.Pretty)
%%]

%%[20 import(qualified EH.Util.SPDoc as SP)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% CfgPP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 export(CfgPP(..))
class CfgPP x where
  cfgppHsName 		:: x -> HsName -> PP_Doc
  cfgppConHsName 	:: x -> HsName -> PP_Doc
  cfgppUID    		:: x -> UID    -> PP_Doc
  cfgppVarHsName 	:: x -> Maybe HsName -> Maybe UID -> Maybe Int -> PP_Doc
%%[[20
  cfgspHsName 		:: x -> HsName -> SP.SPDoc
  cfgspConHsName 	:: x -> HsName -> SP.SPDoc
  cfgspUID    		:: x -> UID    -> SP.SPDoc
  cfgspVarHsName 	:: x -> Maybe HsName -> Maybe UID -> Maybe Int -> SP.SPDoc
%%]]
  cfgppFollowAST    :: x -> Bool

  cfgppHsName    _              = pp
  cfgppConHsName _              = ppCon
  cfgppUID       _              = pp
  cfgppVarHsName x _ _ (Just i) = cfgppHsName x $ mkHNm $ tnUniqRepr i
  cfgppVarHsName x (Just n) _ _ = cfgppHsName x n
  cfgppVarHsName x _ (Just u) _ = cfgppUID x u
%%[[20
  cfgspHsName    _              = SP.sp
  cfgspConHsName _              = spCon
  cfgspUID       _              = SP.sp
  cfgspVarHsName x _ _ (Just i) = cfgspHsName x $ mkHNm $ tnUniqRepr i
  cfgspVarHsName x (Just n) _ _ = cfgspHsName x n
  cfgspVarHsName x _ (Just u) _ = cfgspUID x u
%%]]
  cfgppFollowAST _              = False
%%]

%%[8 export(CfgPP_Plain(..),CfgPP_HI(..),CfgPP_Core(..),CfgPP_Grin(..))
data CfgPP_Plain = CfgPP_Plain
data CfgPP_HI    = CfgPP_HI
data CfgPP_Core  = CfgPP_Core
data CfgPP_Grin  = CfgPP_Grin
%%]

%%[8
instance CfgPP CfgPP_Plain
%%]

%%[8
instance CfgPP CfgPP_HI where
  cfgppHsName   _ n
%%[[8
    = ppHsnNonAlpha hiScanOpts n
%%][20
    = case n of
        HNPos i
          -> pp i
        _ -> ppHsnNonAlpha hiScanOpts n
%%]]
  cfgppConHsName x n            = if n == hsnRowEmpty then hsnORow >#< hsnCRow else cfgppHsName x n
  cfgppVarHsName x _ (Just u) _ = cfgppUID x u
  cfgppUID       _ u            = "uid" >#< ppUID' u
%%[[20
  cfgspHsName   _ n
    = case n of
        HNPos i
          -> SP.sp i
        _ -> spHsnNonAlpha hiScanOpts n
  cfgspConHsName x n            = if n == hsnRowEmpty then hsnORow SP.>#< hsnCRow else cfgspHsName x n
  cfgspVarHsName x _ (Just u) _ = cfgspUID x u
  cfgspUID       _ u            = "uid" SP.>#< spUID' u
%%]]
  cfgppFollowAST _              = True
%%]

%%[8
instance CfgPP CfgPP_Core where
  cfgppHsName    _ = ppHsnNonAlpha coreScanOpts
%%[[20
  cfgspHsName    _ = spHsnNonAlpha coreScanOpts
%%]]
%%]

%%[8
instance CfgPP CfgPP_Grin where
  cfgppHsName    _ = ppHsnNonAlpha grinScanOpts
%%[[20
  cfgspHsName    _ = spHsnNonAlpha grinScanOpts
%%]]
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Support utils
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8
tnUniqRepr :: Int -> String
tnUniqRepr
  = lrepr
  where lrepr i = if i <= 26
                  then  [repr i]
                  else  let  (d,r) = i `divMod` 26
                        in   (repr d : lrepr r)
        repr    = (chr . (97+))
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% pp's which should not be here...
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 export(ppCTag')
-- intended for parsing
ppCTag' :: CfgPP x => x -> CTag -> PP_Doc
ppCTag' x t
  = case t of
      CTagRec                      -> ppCurly "Rec"
      CTag ty nm tag arity mxarity -> ppCurlysSemis' [ppNm ty,ppNm nm,pp tag, pp arity, pp mxarity]
  where ppNm n = cfgppHsName x n
%%]

%%[8 export(ppCTagsMp)
ppCTagsMp :: CfgPP x => x -> CTagsMp -> PP_Doc
ppCTagsMp x
  = mkl (mkl (ppCTag' x))
  where mkl pe = ppCurlysSemisBlock . map (\(n,e) -> cfgppHsName x n >-< indent 1 ("=" >#< pe e))
%%]

%%[20
instance PPForHI CTag where
  ppForHI = ppCTag' CfgPP_HI
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% PP variants for: HI
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[20 export(PPForHI(..))
class (PP x) => PPForHI x where
  ppForHI :: x -> PP_Doc

  ppForHI = pp
%%]
class (SP.SP x, PP x) => PPForHI x where
  ppForHI :: x -> PP_Doc
  spForHI :: x -> SP.SPDoc

  ppForHI = pp . spForHI
  spForHI = SP.sp . ppForHI

%%[20
instance PPForHI UID where
  ppForHI = cfgppUID CfgPP_HI

instance PPForHI HsName where
  ppForHI = cfgppHsName CfgPP_HI

instance PPForHI Int
%%]
