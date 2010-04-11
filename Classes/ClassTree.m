//
//  ClassTree.m
//  ClassBrowser
//

#import <dlfcn.h>
#import <objc/runtime.h>
#import "ClassTree.h"

@implementation ClassTree

@synthesize classDictionary = classDictionary_;
@synthesize subclassesDataSource = subclassesDataSource_;
@synthesize subclassesWithImageSectionsDataSource = subclassesWithImageSectionsDataSource_;

static ClassTree *sharedClassTreeInstance = nil;


+ (ClassTree*)sharedClassTree {
    @synchronized(self) {
        if (sharedClassTreeInstance == nil) {
            [[self alloc] init]; // assignment not done here
        }
    }
    return sharedClassTreeInstance;
}


+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedClassTreeInstance == nil) {
            sharedClassTreeInstance = [super allocWithZone:zone];
            return sharedClassTreeInstance;  // assignment and return on first allocation
        }
    }
    return nil; //on subsequent allocation attempts return nil
}


- (id)copyWithZone:(NSZone *)zone {
    return self;
}


- (id)retain {
    return self;
}


- (unsigned)retainCount {
    return UINT_MAX;  //denotes an object that cannot be released
}


- (void)release {
    //do nothing
}


- (id)autorelease {
    return self;
}


- (void)dealloc {
	[classDictionary_ release];
	[subclassesDataSource_ release];
	[subclassesWithImageSectionsDataSource_ release];
	[super dealloc];
}


- (void)setupClassDictionary {
	classDictionary_ = [[NSMutableDictionary alloc]initWithCapacity:3000];
	NSMutableDictionary *subclassDictionary = [[NSMutableDictionary alloc] initWithCapacity:0];
	[classDictionary_ setObject:subclassDictionary forKey:KEY_ROOT_CLASSES];
	[subclassDictionary release];
	
	NSString *applicationBundlePath = [[NSBundle mainBundle] bundlePath];
	
	int numberOfClasses = objc_getClassList(NULL,0);
	Class classes[numberOfClasses];
	if (objc_getClassList(classes,numberOfClasses)) {
		for (int i = 0; i < numberOfClasses; i++) {
			Class class = classes[i];
			NSString *className = nil;
			NSString *subClassName = nil;
			const char *imageName = NULL;
			while (class) {
				imageName = class_getImageName(class);
				if (!imageName || 
#if TARGET_IPHONE_SIMULATOR
					!strstr(imageName, "iPhoneSimulator.platform") ||
#endif
					strstr(imageName,"PrivateFrameworks") ||
					strstr(imageName,[applicationBundlePath cStringUsingEncoding:NSNEXTSTEPStringEncoding])) {
					subClassName = nil;
					break;
				}
				className = [NSString stringWithCString:class_getName(class) encoding:NSNEXTSTEPStringEncoding];
				NSRange range = [className rangeOfString:@"webkit" options:NSCaseInsensitiveSearch];
				if (range.location != NSNotFound ) {
					subClassName = nil;
					break;
				}
				range = [className rangeOfString:@"private" options:NSCaseInsensitiveSearch];
				if (range.location != NSNotFound ) {
					subClassName = nil;
					break;
				}
				if (!(subclassDictionary = [classDictionary_ objectForKey:className])) {
					subclassDictionary = [[NSMutableDictionary alloc] initWithCapacity:0];
					[classDictionary_ setObject:subclassDictionary forKey:className];
					[subclassDictionary release];
				}
				if (subClassName) {
					[subclassDictionary setObject:[classDictionary_ objectForKey:subClassName] forKey:subClassName];
				}
				subClassName = className;
				class = class_getSuperclass(class);
			}
			if (subClassName) {
				[[classDictionary_ objectForKey:KEY_ROOT_CLASSES] setObject:[classDictionary_ objectForKey:subClassName] forKey:subClassName];
			}
		}
	}

	subclassesDataSource_ = [[SubclassesDataSource alloc] initWithArray:[classDictionary_ allKeys]];
	subclassesWithImageSectionsDataSource_ = [[SubclassesWithImageSectionsDataSource alloc] initWithArray:[classDictionary_ allKeys]];
}


#define kLAST_CACHED_SYSTEM_VERSION @"lastCachedSystemVersion"
#define kALL_LOADABLE_LIBRARIES_PATH_CACHE @"allLoadableLibrariesPathCache"


- (void)loadAllFrameworks {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *lastRunSystemVersion = [defaults stringForKey:kLAST_CACHED_SYSTEM_VERSION];
	NSArray *allLoadableLibrariesPathCache = [defaults arrayForKey:kALL_LOADABLE_LIBRARIES_PATH_CACHE];
	if ([lastRunSystemVersion isEqualToString:[[UIDevice currentDevice]systemVersion]] &&
		[allLoadableLibrariesPathCache count] > 0) {
		
		for (NSString *libraryPath in allLoadableLibrariesPathCache) {
			if (!dlopen([libraryPath cStringUsingEncoding:NSNEXTSTEPStringEncoding],RTLD_NOW|RTLD_GLOBAL)) {
				NSLog(@"dlopen fail:%@",libraryPath);
			}
		}
		
	} else {
		NSMutableArray *allLoadableLibrariesPath = [NSMutableArray array];
		
		NSArray *allLibrariesPath = NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory,NSSystemDomainMask,NO);
		NSArray *ignorePaths = NSSearchPathForDirectoriesInDomains(NSDeveloperDirectory,NSSystemDomainMask,NO);
		NSMutableArray *searchPaths = [allLibrariesPath mutableCopy];
		[searchPaths removeObjectsInArray:ignorePaths];
		for (NSString *path in searchPaths) {
			NSString *file, *libraryPath;
			NSDirectoryEnumerator *dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:path];
			while (file = [dirEnum nextObject]) {
				NSArray *components = [file pathComponents];
				if ([components count] > 1 &&
					[[components lastObject] hasSuffix: @".framework"]) {
					libraryPath = [[path stringByAppendingPathComponent:file] stringByAppendingPathComponent:[[components lastObject] stringByDeletingPathExtension]];
					if (dlopen([libraryPath cStringUsingEncoding:NSNEXTSTEPStringEncoding],RTLD_NOW|RTLD_GLOBAL)) {
						[allLoadableLibrariesPath addObject:libraryPath];
					} else {
						NSLog(@"dlopen fail:%@",libraryPath);
					}
				}
			}
		}
		[searchPaths release];
		
		[defaults setObject:[[UIDevice currentDevice]systemVersion] forKey:kLAST_CACHED_SYSTEM_VERSION];
		[defaults setObject:allLoadableLibrariesPath forKey:kALL_LOADABLE_LIBRARIES_PATH_CACHE];
		[defaults synchronize];
	}
}


@end
