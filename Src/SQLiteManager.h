//
//  SQLiteManager.h
//
//  Created by Saurabh Sirdeshmukh on 05/04/14 with Champa & Sheru.
//  Copyright (c) 2013 Saurabh Sirdeshmukh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

#define VZ_SQLITE_ERROR_DOMAIN @"SQLiteErrorDomain"

typedef enum{
    VZ_SQLITE_ERROR, //Generic error
    VZ_SQLITE_ERROR_OPEN,//Error opening an SQLite DB.
    VZ_SQLITE_ERROR_CLOSE,//Error closing an SQLite DB.
    VZ_SQLITE_ERROR_BIND,//Error binding params to the prepared statement;insufficient parameters can be one of it.
    VZ_SQLITE_ERROR_PREPARE,//Error preparing the statement.
    VZ_SQLITE_ERROR_TRANSACTION,//Error executing the transaction.
} SQLiteErrorCode;

//TODO: check if Foreign Key constraints setting is on/off. Shall we enforce the FK constraints?

@interface SQLiteManager : NSObject{
    @private
    sqlite3 *db;
    int currentColumnCount;//The number of columns in the result set of the currently executed query.
    sqlite3_stmt *statement;//The prepared statment corresponding to the currently executed SQL query.
    NSError *dbError;
}

@property (nonatomic, readonly) NSError *dbError;

- (void) openDatabase:(NSString *)dbNameOrPath createIfNeeded:(BOOL) createIfNeeded;
- (void) closeDatabase;

- (int) getColumnCount;
- (NSArray *) getColumns;
- (NSInteger) getLastInsertRowId;

- (BOOL) executeQuery:(NSString *) query withParams:(NSArray *) params;
- (BOOL) executeUpdate:(NSString *) query withParams:(NSArray *) params;
//- (BOOL) executeTransaction:(NSString *) query withParamSets:(NSArray *) paramSets withTarget:(id) aTarget andSelector:(SEL) aSelector;

- (NSArray *) getNextRowAsArray;
- (NSDictionary *) getNextRowAsDictionary;
- (NSArray *) getResultSetForQuery:(NSString *) query withParams:(NSArray *) params;

@end
