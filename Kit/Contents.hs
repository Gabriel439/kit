module Kit.Contents (
  KitContents(..),
  readKitContents,
  namedPrefix
  ) where

import Kit.Spec
import Kit.Util
import Kit.Xcode.XCConfig
import Kit.FilePath

-- | The determined contents of a particular Kit
data KitContents = KitContents { 
  contentSpec :: KitSpec, -- ^ The dependency the contents were created from
  contentBaseDir :: FilePath, -- ^ Path to where the content was loaded from
  contentHeaders :: [FilePath],     -- ^ Paths to headers
  contentSources :: [FilePath],     -- ^ Paths to source files
  contentLibs :: [FilePath],        -- ^ Paths to static libs
  contentConfig :: Maybe XCConfig,  -- ^ Contents of the xcconfig base file
  contentPrefix :: Maybe String,     -- ^ Contents of the prefix header
  contentResourceDir :: Maybe FilePath
}

instance Packageable KitContents where
  packageName = packageName . contentSpec
  packageVersion = packageVersion . contentSpec

namedPrefix :: KitContents -> Maybe String
namedPrefix kc = fmap (\s -> "//" ++ packageFileName kc ++ "\n" ++ s) $ contentPrefix kc

readKitContents :: (Applicative m, MonadIO m) => AbsolutePath -> KitSpec -> m KitContents
readKitContents absKitDir spec =
  let kitDir = filePath absKitDir 
      find dir tpe = liftIO $ inDirectory kitDir $ do
        files <- glob (dir </> "**/*" ++ tpe)
        mapM canonicalizePath files
      findSrc = find $ specSourceDirectory spec
      headers = findSrc ".h"
      sources = findSrc .=<<. [".m", ".mm", ".c"]
      libs = find (specLibDirectory spec) ".a" 
      config = liftIO $ readConfig kitDir spec
      prefix = liftIO $ readHeader kitDir spec
      resourceDir = liftIO $ do
        let r = kitDir </> specResourcesDirectory spec
        b <- doesDirectoryExist r
        if b 
          then Just <$> canonicalizePath r
          else return Nothing
   in KitContents spec kitDir <$> headers <*> sources <*> libs <*> config <*> prefix <*> resourceDir

-- TODO report missing file
readHeader :: FilePath -> KitSpec -> IO (Maybe String)
readHeader kitDir spec = readFile' $ kitDir </> specPrefixFile spec

-- TODO report missing file
readConfig :: FilePath -> KitSpec -> IO (Maybe XCConfig)
readConfig kitDir spec = do
  contents <- readFile' $ kitDir </> specConfigFile spec
  return $ fmap (fileContentsToXCC $ packageName spec) contents

