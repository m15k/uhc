%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% EHC Compile Phase building blocks: parsers
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

CompilePhase building blocks: parsers

%%[8 module {%{EH}EHC.CompilePhase.Parsers}
%%]

%%[8 import(UU.Parsing, UU.Parsing.Offside)
%%]
%%[8 import(qualified UHC.Util.ScanUtils as ScanUtils, {%{EH}Scanner.Common})
%%]
%%[8 import(UHC.Util.ParseUtils)
%%]
%%[99 import(Control.Exception as CE)
%%]

%%[8 import({%{EH}EHC.Common})
%%]
%%[8 import({%{EH}EHC.CompileUnit})
%%]
%%[8 import({%{EH}EHC.CompileRun})
%%]
-- EH parser
%%[8 import(qualified {%{EH}EH} as EH, qualified {%{EH}EH.Parser} as EHPrs)
%%]
-- HS parser
%%[8 import(qualified {%{EH}HS} as HS, qualified {%{EH}HS.Parser} as HSPrs)
%%]
-- HI parser
%%[50 import(qualified {%{EH}HI} as HI)
%%]
-- Core parser
%%[(50 codegen) import(qualified {%{EH}Core} as Core, qualified {%{EH}Core.Parser} as CorePrs)
%%]
-- TyCore parser
%%[(50 codegen tycore) import(qualified {%{EH}TyCore} as C)
%%]
-- Grin parser
%%[(8 codegen grin) import(qualified {%{EH}GrinCode} as Grin, qualified {%{EH}GrinCode.Parser} as GrinParser)
%%]

-- serialization
%%[50 import(qualified UHC.Util.Binary as Bin, UHC.Util.Serialize)
%%]
-- config
%%[50 import(qualified {%{EH}Config} as Cfg)
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Compile actions: parsing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[8 export(cpParseOffside)
cpParseOffsideWithFPath :: HSPrs.HSParser a -> ScanUtils.ScanOpts -> EcuUpdater a -> String -> Maybe FPath -> HsName -> EHCompilePhase ()
cpParseOffsideWithFPath parser scanOpts store description mbFp modNm
 = do { cr <- get
      ; (fn,fh) <- lift $ openFPath (maybe (ecuFilePath (crCU modNm cr)) id mbFp) ReadMode False
      ; tokens  <- lift $ offsideScanHandle scanOpts fn fh
      -- ; lift $ putStrLn $ show tokens -- does not work, no Show instance
      ; let (res,msgs) = parseOffsideToResMsgs parser tokens
            errs       = map (rngLift emptyRange mkPPErr) msgs
      ; cpUpdCU modNm (store res)
      ; cpSetLimitErrsWhen 5 description errs
      }
      
cpParseOffside :: HSPrs.HSParser a -> ScanUtils.ScanOpts -> EcuUpdater a -> String -> HsName -> EHCompilePhase ()
cpParseOffside parser scanOpts store description modNm
 = cpParseOffsideWithFPath parser scanOpts store description Nothing modNm
%%]

%%[8 export(cpParsePlain)
cpParsePlainWithHandleToErrs :: PlainParser Token a -> ScanUtils.ScanOpts -> EcuUpdater a -> (String, Handle) -> HsName -> EHCompilePhase [Err]
cpParsePlainWithHandleToErrs parser scanOpts store (fn,fh) modNm
 = do { cr <- get
      ; tokens  <- lift $ scanHandle scanOpts fn fh
      ; let (res,msgs) = parseToResMsgs parser tokens
            errs       = map (rngLift emptyRange mkPPErr) msgs
      ; when (null errs)
             (cpUpdCU modNm (store res))
      ; return errs
      }

cpParsePlainToErrs :: PlainParser Token a -> ScanUtils.ScanOpts -> EcuUpdater a -> FPath -> HsName -> EHCompilePhase [Err]
cpParsePlainToErrs parser scanOpts store fp modNm
 = do { fnfh@(fn,fh) <- lift $ openFPath fp ReadMode False
      ; cpParsePlainWithHandleToErrs parser scanOpts store fnfh modNm
      }

cpParsePlain :: PlainParser Token a -> ScanUtils.ScanOpts -> EcuUpdater a -> String -> FPath -> HsName -> EHCompilePhase ()
cpParsePlain parser scanOpts store description fp modNm
 = do { errs <- cpParsePlainToErrs parser scanOpts store fp modNm
      ; cpSetLimitErrsWhen 5 description errs
      }
%%]

%%[8 export(cpParseEH)
cpParseEH :: HsName -> EHCompilePhase ()
cpParseEH
  = cpParseOffside EHPrs.pAGItf (ehScanOpts defaultEHCOpts) ecuStoreEH "Parse (EH syntax) of module"
%%]

%%[(8 grin) export(cpParseGrin)
cpParseGrin :: HsName -> EHCompilePhase ()
cpParseGrin modNm
  = do { cr <- get
       ; let  (ecu,_,opts,fp) = crBaseInfo modNm cr
              fpC     = fpathSetSuff "grin" fp
       ; cpMsg' modNm VerboseALot "Parsing" Nothing fpC
       ; cpParsePlain GrinParser.pModule grinScanOpts ecuStoreGrin "Parse grin" fpC modNm
       ; return ()
       }
%%]

%%[8.cpParseHs export(cpParseHs)
cpParseHs :: HsName -> EHCompilePhase ()
cpParseHs modNm
  = do { cr <- get
       ; let (_,opts) = crBaseInfo' cr
       ; cpParseOffside (HSPrs.pAGItf opts) (hsScanOpts opts) ecuStoreHS "Parse (Haskell syntax) of module" modNm
       }
%%]

%%[99 -8.cpParseHs export(cpParseHs)
cpParseHs :: Bool -> HsName -> EHCompilePhase ()
cpParseHs litmode modNm
  = do { cr <- get
       ; let  (ecu,_,opts,_) = crBaseInfo modNm cr
       ; cpParseOffsideWithFPath
           (HSPrs.pAGItf opts) ((hsScanOpts opts) {ScanUtils.scoLitmode = litmode}) ecuStoreHS
           ("Parse (" ++ (if litmode then "Literate " else "") ++ "Haskell syntax) of module")
           Nothing modNm
       }
%%]

%%[50 export(cpParseOffsideStopAtErr)
cpParseOffsideStopAtErr :: HSPrs.HSParser a -> ScanUtils.ScanOpts -> EcuUpdater a -> HsName -> EHCompilePhase ()
cpParseOffsideStopAtErr parser scanOpts store modNm
 = do { cr <- get
      ; (fn,fh) <- lift $ openFPath (ecuFilePath (crCU modNm cr)) ReadMode False
      ; tokens  <- lift $ offsideScanHandle scanOpts fn fh
      ; let (res,_) = parseOffsideToResMsgsStopAtErr parser tokens
      ; cpUpdCU modNm (store res)
      }
%%]

%%[50.cpParseHsImport export(cpParseHsImport)
cpParseHsImport :: HsName -> EHCompilePhase ()
cpParseHsImport modNm
  = do { cr <- get
       ; let (_,opts) = crBaseInfo' cr
       ; cpParseOffsideStopAtErr (HSPrs.pAGItfImport opts) (hsScanOpts opts) ecuStoreHS modNm
       }
%%]

%%[99 -50.cpParseHsImport export(cpParseHsImport)
cpParseHsImport :: Bool -> HsName -> EHCompilePhase ()
cpParseHsImport litmode modNm
  = do { cr <- get
       ; let (_,opts) = crBaseInfo' cr
       ; cpParseOffsideStopAtErr (HSPrs.pAGItfImport opts) ((hsScanOpts opts) {ScanUtils.scoLitmode = litmode}) ecuStoreHS modNm
       }
%%]

%%[(50 codegen) export(cpParseCore)
cpParseCore :: HsName -> EHCompilePhase ()
cpParseCore modNm
  = do { cr <- get
       ; let  (ecu,_,opts,fp) = crBaseInfo modNm cr
              fpC     = fpathSetSuff "core" fp
       ; cpMsg' modNm VerboseALot "Parsing" Nothing fpC
       ; errs <- cpParsePlainToErrs CorePrs.pCModule (coreScanOpts opts) ecuStoreCore fpC modNm
       ; when (ehcDebugStopAtCoreError opts)
              (cpSetLimitErrsWhen 5 "Parse Core (of previous compile) of module" errs)
       ; return ()
       }
%%]

%%[5020 export(cpParseHI)
cpParseHI :: HsName -> EHCompilePhase ()
cpParseHI modNm
  = do { cr <- get
       ; let  (ecu,_,opts,fp) = crBaseInfo modNm cr
%%[[50
              fpH     = fpathSetSuff "hi" fp
%%][99
              -- if outputdir is specified, use that location to possibly read hi from.
              fpH     = mkInOrOutputFPathFor (InputFrom_Loc $ ecuFileLocation ecu) opts modNm fp "hi"
%%]]
       ; cpMsg' modNm VerboseALot "Parsing" Nothing fpH
       ; fnfh <- lift $ openFPath fpH ReadMode False
       ; errs <- cpParsePlainWithHandleToErrs HIPrs.pAGItf (hiScanOpts opts) ecuStorePrevHI fnfh modNm
       ; when (ehcDebugStopAtHIError opts)
              (cpSetLimitErrsWhen 5 "Parse HI (of previous compile) of module" errs)
       ; return ()
       }
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Compile actions: Binary reading
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[50 export(cpDecodeHIInfo)
cpDecodeHIInfo :: HsName -> EHCompilePhase ()
cpDecodeHIInfo modNm
  = do { cr <- get
       ; let  (ecu,_,opts,fp) = crBaseInfo modNm cr
%%[[50
              fpH     = fpathSetSuff "hi" fp
%%][99
              -- if outputdir is specified, use that location to possibly read hi from.
              fpH     = mkInOrOutputFPathFor (InputFrom_Loc $ ecuFileLocation ecu) opts modNm fp "hi"
%%]]
       ; cpMsg' modNm VerboseALot "Decoding" Nothing fpH
       ; hiinfo <- lift $
           CE.catch (do { i <- getSGetFile (fpathToStr fpH) (HI.sgetHIInfo opts)
                               -- getSerializeFile (fpathToStr fpH)
                               -- Bin.getBinaryFPath fpH
                        ; return i
                        })
                    (\(_ :: SomeException) -> return $ HI.emptyHIInfo {HI.hiiValidity = HI.HIValidity_Absent})
       ; when (ehcOptVerbosity opts > VerboseALot)
              (do { lift $ putPPLn (pp hiinfo)
                  })
%%[[99
       ; let canCompile = crModCanCompile modNm cr
%%]]
       ; case HI.hiiValidity hiinfo of
%%[[99
           HI.HIValidity_WrongMagic | not canCompile
             -> cpSetLimitErrsWhen 1 "Read HI"
                  [rngLift emptyRange Err_WrongMagic
                     (show modNm)
                     (fpathToStr fpH)
                  ]
           HI.HIValidity_Inconsistent | not canCompile
             -> cpSetLimitErrsWhen 1 "Read HI (of previous compile) of module"
                  [rngLift emptyRange Err_InconsistentHI
                     (show modNm)
                     (fpathToStr fpH)
                     [Cfg.verTimestamp Cfg.version, Cfg.installVariant opts, show $ ehcOptTarget opts  , show $ ehcOptTargetFlavor opts  ]
                     [HI.hiiSrcTimeStamp hiinfo   , HI.hiiCompiler hiinfo  , show $ HI.hiiTarget hiinfo, show $ HI.hiiTargetFlavor hiinfo]
                  ]
%%]]
           _ -> cpUpdCU modNm (ecuStorePrevHIInfo {- $ HI.hiiPostCheckValidity opts -} hiinfo)
       }
%%]

%%[50
-- | Decode from serialized file and store result in the compileunit for the module modNm
cpDecode :: Serialize x => String -> EcuUpdater x -> HsName -> EHCompilePhase ()
cpDecode suff store modNm
  = do { cr <- get
       ; let  (ecu,_,opts,fp) = crBaseInfo modNm cr
              fpC     = fpathSetSuff suff fp
       ; cpMsg' modNm VerboseALot "Decoding" Nothing fpC
       ; x <- lift $ getSerializeFile (fpathToStr fpC)
       ; cpUpdCU modNm (store x)
       }
%%]

%%[50 export(cpDecodeGrin)
cpDecodeGrin :: HsName -> EHCompilePhase ()
cpDecodeGrin = cpDecode "grin" ecuStoreGrin
%%]

%%[50 export(cpDecodeCore)
cpDecodeCore :: HsName -> EHCompilePhase ()
cpDecodeCore = cpDecode "core" ecuStoreCore
%%]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Compile actions: on top of parsing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%[50 export(cpGetPrevHI)
cpGetPrevHI :: HsName -> EHCompilePhase ()
cpGetPrevHI modNm
  = do { cr <- get
       ; let  ecu        = crCU modNm cr
       -- ; when (isJust (ecuMbHITime ecu))
       --        (cpParseHI modNm)
       ; when (isJust (ecuMbHIInfoTime ecu))
              (cpDecodeHIInfo modNm)
       }
%%]

%%[(50 codegen) export(cpGetPrevCore)
cpGetPrevCore :: HsName -> EHCompilePhase ()
cpGetPrevCore modNm
  = do { cr <- get
       ; let  ecu    = crCU modNm cr
       ; when (isJust (ecuMbCoreTime ecu) && isNothing (ecuMbCore ecu))
              (cpDecodeCore modNm)
              -- (cpParseCore modNm)
       }
%%]

%%[(50 codegen) export(cpGetPrevGrin)
cpGetPrevGrin :: HsName -> EHCompilePhase ()
cpGetPrevGrin modNm
  = do { cr <- get
       ; let  ecu    = crCU modNm cr
       ; when (isJust (ecuMbGrinTime ecu) && isNothing (ecuMbGrin ecu))
              (cpDecodeGrin modNm) -- (cpParseGrin modNm)
       }
%%]


