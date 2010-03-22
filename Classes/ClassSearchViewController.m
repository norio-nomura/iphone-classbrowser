//
//  ClassSearchViewController.m
//  ClassBrowser
//

#import <objc/runtime.h>
#import "ClassSearchViewController.h"
#import "ClassBrowserAppDelegate.h"
#import "ClassTree.h"
#import "SubclassesDataSource.h"
#import "SubclassesWithImageSectionsDataSource.h"

@implementation ClassSearchViewController

@synthesize tableView;
@synthesize segmentedControl;
@synthesize searchBar;
@synthesize tabBar;
@synthesize dataSourcesArray;
@synthesize initialDataSourcesArray;
@synthesize previousScopeButtonIndex;
@synthesize previousSearchText;


- (void)dealloc {
	[tableView release];
	[segmentedControl release];
	[searchBar release];
	[tabBar release];
	[dataSourcesArray release];
	[initialDataSourcesArray release];
	[previousSearchText release];
    [super dealloc];
}


- (void)loadDataSources {
	NSUInteger tag = 0;
	NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:2];
	self.dataSourcesArray = array;
	[array release];
	array = [[NSMutableArray alloc] initWithCapacity:2];
	self.initialDataSourcesArray = array;
	[array release];
	
	[dataSourcesArray addObject:[ClassTree sharedClassTree].subclassesDataSource];
	[initialDataSourcesArray addObject:[ClassTree sharedClassTree].subclassesDataSource];
	[[tabBar.items objectAtIndex:[dataSourcesArray count] - 1] setTag:tag++];
	
	[dataSourcesArray addObject:[ClassTree sharedClassTree].subclassesWithImageSectionsDataSource];
	[initialDataSourcesArray addObject:[ClassTree sharedClassTree].subclassesWithImageSectionsDataSource];
	[[tabBar.items objectAtIndex:[dataSourcesArray count] - 1] setTag:tag++];
	#pragma unused(tag)
	
	tabBar.selectedItem = [tabBar.items objectAtIndex:0];
	tableView.dataSource = [dataSourcesArray objectAtIndex:tabBar.selectedItem.tag];
	[tableView reloadData];
}


- (void)refreshDataSourcesArray {
	NSString *searchText = self.searchBar.text;
	if (searchText.length > 0) {
		// from subclassesDataSource
		SubclassesDataSource *currentSubclassesDataSource;
		NSMutableArray *filteredArray = [NSMutableArray array];
		switch (self.searchBar.selectedScopeButtonIndex) {
			case 0:
				if (previousScopeButtonIndex == 0 && previousSearchText && NSNotFound != [searchText rangeOfString:previousSearchText options:NSCaseInsensitiveSearch].location) {
					currentSubclassesDataSource = [dataSourcesArray objectAtIndex:0];
				} else {
					currentSubclassesDataSource = [initialDataSourcesArray objectAtIndex:0];
				}
				for (NSArray *classNamesArray in [currentSubclassesDataSource.rows allValues]) {
					for (NSString *className in classNamesArray) {
						if (NSNotFound != [className rangeOfString:searchText options:NSCaseInsensitiveSearch].location) {
							[filteredArray addObject:className];
						}
					}
				}
				break;
			default: {
				if (previousScopeButtonIndex != 0 && previousSearchText && [searchText hasPrefix:previousSearchText]) {
					currentSubclassesDataSource = [dataSourcesArray objectAtIndex:0];
				} else {
					currentSubclassesDataSource = [initialDataSourcesArray objectAtIndex:0];
				}
				NSArray *classNamesArray = [[currentSubclassesDataSource.rows objectForKey:[searchText capitalChar]] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
				for (NSString *className in classNamesArray) {
					NSComparisonResult result = [className compare:searchText options:NSCaseInsensitiveSearch range:NSMakeRange(0, searchText.length)];
					if (result == NSOrderedSame) {
						[filteredArray addObject:className];
					} else if (result == NSOrderedDescending) {
						break;
					}
				}
				break;
			}
		}
		SubclassesDataSource * subclassesDataSource = [[SubclassesDataSource alloc] initWithArray:filteredArray];
		[dataSourcesArray replaceObjectAtIndex:0 withObject:subclassesDataSource];
		[subclassesDataSource release];
		SubclassesWithImageSectionsDataSource *subclassesWithImageSectionsDataSource = [[SubclassesWithImageSectionsDataSource alloc] initWithArray:filteredArray];
		[dataSourcesArray replaceObjectAtIndex:1 withObject:subclassesWithImageSectionsDataSource];
		[subclassesWithImageSectionsDataSource release];
	} else {
		[dataSourcesArray replaceObjectAtIndex:0 withObject:[initialDataSourcesArray objectAtIndex:0]];
		[dataSourcesArray replaceObjectAtIndex:1 withObject:[initialDataSourcesArray objectAtIndex:1]];
	}
}


#pragma mark UIViewController Class


- (void)viewDidLoad {
    [super viewDidLoad];
	self.segmentedControl = [[[UISegmentedControl alloc]initWithItems:[NSArray arrayWithObjects:@"keep",@"tree",nil]]autorelease];
	self.segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
	self.segmentedControl.selectedSegmentIndex = 0;
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:self.segmentedControl]autorelease];
	searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	[self loadDataSources];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


#pragma mark UITableViewDelegate Protocol


- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[aTableView deselectRowAtIndexPath:indexPath animated:NO];
	if (segmentedControl.selectedSegmentIndex == 0) {
		ClassBrowserAppDelegate *appDelegate = (ClassBrowserAppDelegate *)[[UIApplication sharedApplication] delegate];
		[appDelegate pushClass:[[[dataSourcesArray objectAtIndex:tabBar.selectedItem.tag] objectForRowAtIndexPath:indexPath] description]];
	} else if (segmentedControl.selectedSegmentIndex == 1) {
		NSString *className = [[[dataSourcesArray objectAtIndex:tabBar.selectedItem.tag] objectForRowAtIndexPath:indexPath] description];
		NSMutableArray *classNameArray = [[NSMutableArray alloc] initWithObjects:className,nil];
		const char *superClassName = class_getName(class_getSuperclass(objc_getClass([className cStringUsingEncoding:NSNEXTSTEPStringEncoding])));
		/*
		 Based on "Objective-C 2.0 Runtime Reference", superClassName become empty string when superClassName reached rootclasses.
		 So condition will,
		 > while (strlen(superClassName)) {
		 But current class_getName return "nil"
		 */
		while (strcmp(superClassName,"nil")) {
			className = [[NSString alloc] initWithCString:superClassName encoding:NSNEXTSTEPStringEncoding];
			[classNameArray addObject:className];
			[className release];
			superClassName = class_getName(class_getSuperclass(objc_getClass(superClassName)));
		}
		ClassBrowserAppDelegate *appDelegate = (ClassBrowserAppDelegate *)[[UIApplication sharedApplication] delegate];
		appDelegate.autoPushClassNames = classNameArray;
		[classNameArray release];
		[self.navigationController popToRootViewControllerAnimated:YES];
	}
}


#pragma mark UITabBarDelegate Protocol


- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
	tableView.dataSource = [dataSourcesArray objectAtIndex:item.tag];
	[tableView reloadData];
}


#pragma mark UISearchBarDelegate


- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
	[self refreshDataSourcesArray];
	self.previousScopeButtonIndex = selectedScope;

	tableView.dataSource = [dataSourcesArray objectAtIndex:tabBar.selectedItem.tag];
	[tableView reloadData];
}


- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	[self refreshDataSourcesArray];
	self.previousSearchText = searchText;

	tableView.dataSource = [dataSourcesArray objectAtIndex:tabBar.selectedItem.tag];
	[tableView reloadData];
}


- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	if (self.searchBar.text.length > 0) {
		[dataSourcesArray replaceObjectAtIndex:0 withObject:[initialDataSourcesArray objectAtIndex:0]];
		[dataSourcesArray replaceObjectAtIndex:1 withObject:[initialDataSourcesArray objectAtIndex:1]];
		tableView.dataSource = [initialDataSourcesArray objectAtIndex:tabBar.selectedItem.tag];
	}
	
	[tableView reloadData];
	
	[self.searchBar resignFirstResponder];
	self.searchBar.text = @"";
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[self.searchBar resignFirstResponder];
}


- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
	self.searchBar.showsCancelButton = YES;
}


- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	self.searchBar.showsCancelButton = NO;
}


@end
