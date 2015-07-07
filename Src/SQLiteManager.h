//
//  SQLiteManager.h
//
//  Created by Saurabh Sirdeshmukh on 05/04/14 with Champa & Sheru.
//  Copyright (c) 2013 Saurabh Sirdeshmukh. All rights reserved.

/**
 * The MIT License (MIT)
 *
 * Copyright (c) 2015 Saurabh Sirdeshmukh
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 *
 */

#import <Foundation/Foundation.h>
#import <sqlite3.h>

#define SQLITE_ERROR_DOMAIN @"SQLiteErrorDomain"

typedef enum{
    SQLITE_ERROR, //Generic error
    SQLITE_ERROR_OPEN,//Error opening an SQLite DB.
    SQLITE_ERROR_CLOSE,//Error closing an SQLite DB.
    SQLITE_ERROR_BIND,//Error binding params to the prepared statement;insufficient parameters can be one of it.
    SQLITE_ERROR_PREPARE,//Error preparing the statement.
    SQLITE_ERROR_TRANSACTION,//Error executing the transaction.
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
- (BOOL) executeTransaction:(NSString *) query withParamSets:(NSArray *) paramSets withTarget:(id) aTarget andSelector:(SEL) aSelector;

- (NSArray *) getNextRowAsArray;
- (NSDictionary *) getNextRowAsDictionary;
- (NSArray *) getResultSetForQuery:(NSString *) query withParams:(NSArray *) params;

@end
