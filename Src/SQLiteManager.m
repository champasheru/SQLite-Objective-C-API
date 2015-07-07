//
//  SQLiteManager.m
//
//  Created by Saurabh Sirdeshmukh on 05/04/14 with Champa & Sheru.
//  Copyright (c) 2013 Saurabh Sirdeshmukh. All rights reserved.
//

#import "SQLiteManager.h"

@implementation SQLiteManager

@synthesize dbError;

- (instancetype) init{
    if (self=[super init]) {
        db=NULL;
        statement=NULL;
        dbError=nil;
    }
    return self;
}


//Prepare an error object at a single place to be returned to the client of this class.
- (void) prepareError{
    dbError = [NSError errorWithDomain:@"SQLiteErrorDomain" code:sqlite3_errcode(db) userInfo:@{@"errorMessage" : [NSString stringWithCString:sqlite3_errmsg(db) encoding:NSUTF8StringEncoding]}];
    NSLog(@"VZSQLiteManager Error: %@",dbError);
}


- (void) openDatabase:(NSString *)dbNameOrPath createIfNeeded:(BOOL) createIfNeeded{
    int status;
    dbError = nil;
    if (createIfNeeded) {
        status=sqlite3_open_v2([dbNameOrPath cStringUsingEncoding:NSUTF8StringEncoding], &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, NULL);
    }else{
        //By default, sqlite_open is has create+read/write behaviour.
        status=sqlite3_open([dbNameOrPath cStringUsingEncoding:NSUTF8StringEncoding], &db);
    }
    
    if (status!=SQLITE_OK) {
        //Even if some error occures while opening the DB,SQLite returns handle to the sqlite3 structure.
        //So it's imperative to clear the database handle & related resources.
        sqlite3_close(db) ;
        [self prepareError];
    }
}


//This method clears all the bindings for the last prepared statement & finalizes it(i.e clears the memory corresponding to the prepared statement).
- (void) clearState{
    currentColumnCount=0;
    sqlite3_reset(statement);//if the previous prepared statement had any params binded then clear it.
    sqlite3_finalize(statement);
    statement=NULL;
    dbError = nil;
}


- (void) closeDatabase{
    [self clearState];
    sqlite3_close(db);
    /*
     int status=sqlite3_close(db);
     [self prepareError];
     */
}


//This method returns the names of columns pertaining to the result set of the most recently executed query.
//If the prior call to the method executeQuery false/no then the value is undefined.
//This methosd works with executeQuery only.
- (NSArray *) getColumns{
    NSMutableArray *columns=[NSMutableArray arrayWithCapacity:currentColumnCount];
    for (int i=0; i<currentColumnCount; i++) {
        [columns addObject:[NSString  stringWithUTF8String:sqlite3_column_name(statement, i)]];
    }
    return columns;
}


//This method returns the number of columns pertaining to the result set of the most recently executed query.
//If the prior call to the method executeQuery false/no or then the value is undefined.
//This methosd works with executeQuery only.
- (int) getColumnCount{
    return currentColumnCount;
}


//This method should be used to get the ROWID of the last inserted row where the ROWID is a column with attributes:Primary key+Integer(
//can be Autoincrement as well but not necessary).
//If the prior call to executeUdate returns false/no then the retunred value is undefined.
- (NSInteger) getLastInsertRowId{
    return (NSInteger)sqlite3_last_insert_rowid(db);
}


//This method should be used for performing the data retrieval with SELECT clause.
//If there are any parameters in the query that are to be bound, then those are passed as an array. The 0th element in array will
//bind to 1st parameter in the query & so on. If the query has no parameters then pass nil for params.
- (BOOL) executeQuery:(NSString *) query withParams:(NSArray *) params{
    if (statement!=NULL) {
        //Suppose for the previous query/update, the prepared statement was not reclaimed/mem-cleared
        //then first clear the memory corresponding to this statement.This might happen if not all the
        //records from the result set were interated over. In that statement remained valid in memory.
        [self clearState];
    }
    
    BOOL didBind=YES;
    const char *cQuery=[query cStringUsingEncoding:NSUTF8StringEncoding];
    int status=sqlite3_prepare_v2(db,cQuery,-1, &statement, NULL);
    
    //If there's an error compiling/preparing the statement then it's set to NULL.
    if (status==SQLITE_OK && statement!=NULL) {
        //NSLog(@"executeQuery Bind params count: %d",sqlite3_bind_parameter_count(statement));
        int numParams=sqlite3_bind_parameter_count(statement);
        
        if (numParams>0 && (params==nil || params.count!=numParams)) {
            didBind=NO;
            dbError = [NSError errorWithDomain:VZ_SQLITE_ERROR_DOMAIN code:VZ_SQLITE_ERROR_BIND userInfo:nil];
        }else if (numParams>0) {
            for (int i=0; i<numParams; i++) {
                id aParam=[params objectAtIndex:i];
                
                if ([aParam isKindOfClass:[NSNumber class]]) {
                    NSNumber *aNumber=aParam;
                    if (strcmp([aNumber objCType],@encode(float)) ||  strcmp([aNumber objCType],@encode(double))){
                        status=sqlite3_bind_double(statement, i+1, [aNumber doubleValue]);
                    }else if(strcmp([aNumber objCType],@encode(int)) || strcmp([aNumber objCType],@encode(NSInteger)) || strcmp([aNumber objCType],@encode(BOOL))){
                        status=sqlite3_bind_int(statement, i+1, [aNumber intValue]);
                    }else if(strcmp([aNumber objCType],@encode(long)) || strcmp([aNumber objCType],@encode(long long)) || strcmp([aNumber objCType],@encode(NSUInteger))){
                        status=sqlite3_bind_int64(statement, i+1, [aNumber longValue]);
                    }else{
                        //Default: If nothing above matches, bind to int.
                        //E.g. like short, unsigned short, unsigned long etc.
                        status=sqlite3_bind_int(statement, i+1, [aNumber intValue]);
                    }
                }else if([aParam isKindOfClass:[NSString class]]){
                    NSString *aString=aParam;
                    NSData *aData=[aString dataUsingEncoding:NSUTF8StringEncoding];
                    status=sqlite3_bind_text(statement, i+1, [aString cStringUsingEncoding:NSUTF8StringEncoding], (int)[aData length], SQLITE_TRANSIENT);
                }else if([aParam isKindOfClass:[NSData class]]){
                    NSData *aData=aParam;
                    status=sqlite3_bind_blob(statement, i+1, [aData bytes], (int)[aData length], SQLITE_TRANSIENT);
                }else if(aParam==[NSNull null]){
                    status=sqlite3_bind_null(statement, i+1);
                }
                
                if (status!=SQLITE_OK) {
                    didBind=NO;
                    dbError = [NSError errorWithDomain:VZ_SQLITE_ERROR_DOMAIN code:VZ_SQLITE_ERROR_BIND userInfo:nil];
                    NSLog(@"executeQuery Error: Binding the parameter at: %d",i);
                    break;
                }
            }
        }
    }
    
    if (status==SQLITE_OK && statement!=NULL && didBind) {
        currentColumnCount=sqlite3_column_count(statement);
        return YES;
    }
    
    dbError = [NSError errorWithDomain:VZ_SQLITE_ERROR_DOMAIN code:VZ_SQLITE_ERROR_PREPARE userInfo:nil];
    NSLog(@"[VZSQLiteManager] Error:executeQuery preparing the statement: %@ Error: %s",query,sqlite3_errmsg(db));
    return NO;
}



//This method shoud be used for performing changes to the DB with INSERT,UPDATE,DELETE clause.
//By default the Auto-commit mode is enabled for SQLite.
//W.r.t. executing the updates, the INSERTS are automic by default & are executed as transactions as mentioned in docs:
//http://sqlite.org/faq.html#q19
//http://sqlite.org/atomiccommit.html
//This update may be executed as a transaction (or as a part of transaction) or as single/stand-alone SQL statement.
//If it's standalone statement & error occures while executing the statement then following rule applies:
//1.If auto-commit mode of SQLite is enabled(which is the default case), the rollbacking the transaction is taken care by SQLite iteself.
//2.If auto-commit is disabled, this method explicitely rollbacks the transaction.
//If there are any parameters in the query that are to be bound, then those are passed as an array. The 0th element in array will
//bind to 1st parameter in the query & so on. If the query has no parameters then pass nil for params.
- (BOOL) executeUpdate:(NSString *) query withParams:(NSArray *) params{
    if (statement!=NULL) {
        //Suppose for the previous query/update, the prepared statement was not reclaimed/mem-cleared
        //then first clear the memory corresponding to this statement.This might happen if not all the
        //records from the result set were interated over. In that statement remained valid in memory.
        [self clearState];
    }
    // End
    
    BOOL didBind=YES;
    const char *cQuery=[query cStringUsingEncoding:NSUTF8StringEncoding];
    int status=sqlite3_prepare_v2(db,cQuery,-1, &statement, NULL);
    
    if (status==SQLITE_OK && statement!=NULL) {
        //NSLog(@"executeUpdate Bind params count: %d",sqlite3_bind_parameter_count(statement));
        int numParams=sqlite3_bind_parameter_count(statement);
        if (numParams>0 && (params==nil || params.count!=numParams)) {
            didBind=NO;
            dbError = [NSError errorWithDomain:VZ_SQLITE_ERROR_DOMAIN code:VZ_SQLITE_ERROR_BIND userInfo:nil];
        }else if (numParams>0) {
            for (int i=0; i<numParams; i++) {
                id aParam=[params objectAtIndex:i];
                if ([aParam isKindOfClass:[NSNumber class]]) {
                    NSNumber *aNumber=aParam;
                    if (strcmp([aNumber objCType],@encode(float)) ||  strcmp([aNumber objCType],@encode(double))){
                        status=sqlite3_bind_double(statement, i+1, [aNumber doubleValue]);
                    }else if(strcmp([aNumber objCType],@encode(int)) || strcmp([aNumber objCType],@encode(NSInteger))){
                        status=sqlite3_bind_int(statement, i+1, [aNumber intValue]);
                    }else if(strcmp([aNumber objCType],@encode(long)) || strcmp([aNumber objCType],@encode(long long)) || strcmp([aNumber objCType],@encode(NSUInteger))){
                        status=sqlite3_bind_int64(statement, i+1, [aNumber longValue]);
                    }else{
                        //Default: If nothing above matches, bind to int.
                        //E.g. like short, unsigned short, unsigned long etc.
                        status=sqlite3_bind_int(statement, i+1, [aNumber intValue]);
                    }
                }else if([aParam isKindOfClass:[NSString class]]){
                    NSString *aString=aParam;
                    NSData *aData=[aString dataUsingEncoding:NSUTF8StringEncoding];
                    status=sqlite3_bind_text(statement, i+1, [aString cStringUsingEncoding:NSUTF8StringEncoding], (int)[aData length], SQLITE_TRANSIENT);
                }else if([aParam isKindOfClass:[NSData class]]){
                    NSData *aData=aParam;
                    status=sqlite3_bind_blob(statement, i+1, [aData bytes], (int)[aData length], SQLITE_TRANSIENT);
                }else if(aParam==[NSNull null]){
                    status=sqlite3_bind_null(statement, i+1);
                }
                
                if (status!=SQLITE_OK) {
                    didBind=NO;
                    dbError = [NSError errorWithDomain:VZ_SQLITE_ERROR_DOMAIN code:VZ_SQLITE_ERROR_BIND userInfo:nil];
                    NSLog(@"executeQuery Error: Binding the parameter at: %d",i);
                    break;
                }
            }
            
        }//end of if numParams>0
        
        if (didBind) {
            //Status is SQLITE_DONE on successful execution.
            status=sqlite3_step(statement);
        }
    }
    
    if (status==SQLITE_DONE && didBind && statement!=NULL) {//Possibly needs to re-look at this flag checking.
        return YES;
    }else if(!sqlite3_get_autocommit(db)){
        //When the Auto-commit mode is On,there's no need to manually/explicitly rollback the transaction as the SQLite takes
        //the responsibility of doing the rollback.
        //NSLog(@"Error:executeUpdate Auto-commit off;Rollbacking the transaction \nError details: %s for query:%@",sqlite3_errmsg(db),query);
        sqlite3_exec(db, "ROLLBACK", NULL, NULL, NULL);
        dbError = [NSError errorWithDomain:VZ_SQLITE_ERROR_DOMAIN code:VZ_SQLITE_ERROR_TRANSACTION userInfo:nil];
    }else{
        dbError = [NSError errorWithDomain:VZ_SQLITE_ERROR_DOMAIN code:VZ_SQLITE_ERROR_PREPARE userInfo:nil];
    }
    
    NSLog(@"[VZSQLiteManager] Error:executeUpdate \nError details: %s for query:%@ status = %d",sqlite3_errmsg(db),query,status);
    return NO;
}



//This method should be used to execute the multiple SQL statements as the transaction.
//It internally calls executeQuery & executeUpdate for exceuting the statements.In case the transaction aborts & couldn't be run
//till completion then the following rules apply:
//1.If auto-commit mode of SQLite is enabled(which is the default case), the rollbacking the transaction is taken care by SQLite iteself.
//2.If auto-commit is disabled, this method explicitely rollbacks the transaction.
//As SELECT statements don't perform changes on the DB,there is no need to rollback them.
//For each SELECT statement, this method invokes the supplied selector for each row in the result set;the selector must have the
//following parameters:
//1st parameter contains the index of SQL statement in the transaction
//2nd parameter contains the row retrieved from the result set after executing the SELECT statement at corresponding index.
//So if there are 4 statements on the transaction & the 3rd is SELECT statement then parametrs will have following values in them:
//1st: 2 (as SQL statmenets in the transaction are counted starting from 0,the index of 3rd statement would be 2)
//2nd argument: row which is returned as NSDictionary so the user can look up the column names & retrieve the corresponding values.
//params is the array of the arrays that supply the values to bind to the parameters for the each statement in the transaction.
//If the statement has no parameters add nil to the array. If all the statements in the transaction are sans parameters then pass
//nil for the paramSets.
- (BOOL) executeTransaction:(NSString *) query withParamSets:(NSArray *) paramSets withTarget:(id) aTarget andSelector:(SEL) aSelector{
    BOOL status=NO;
    
    NSArray *temp=[query componentsSeparatedByString:@"\n"];
    NSMutableArray *multipleQueries=[[NSMutableArray alloc] init];
    
    if ([temp count]>0) {
        [multipleQueries addObjectsFromArray:temp];
    }
    if (!sqlite3_get_autocommit(db)) {
        [multipleQueries insertObject:@"BEGIN TRANSACTION" atIndex:0];
        [multipleQueries addObject:@"COMMIT"];
    }
    
    for (int i=0; i<[multipleQueries count]; i++) {
        BOOL isSelectQuery=NO;
        id params=paramSets?[paramSets objectAtIndex:i]:nil;
        params=(params==[NSNull null])?nil:params;
        
        if ([[multipleQueries objectAtIndex:i] hasPrefix:@"SELECT"]) {
            isSelectQuery=YES;
            status=[self executeQuery:[multipleQueries objectAtIndex:i] withParams:params];
        }else{
            status=[self executeUpdate:[multipleQueries objectAtIndex:i] withParams:params];
        }
        if (!status) {
            //NSLog(@"Error:executeTransaction \nError Details:%s for query:%@",sqlite3_errmsg(db),[multipleQueries objectAtIndex:i]);
            if(!sqlite3_get_autocommit(db)){
                //NSLog(@"Error:executeTransaction Auto-commit off;Rollbacking the transaction \nError details: %s for query:%@",sqlite3_errmsg(db),query);
                sqlite3_exec(db, "ROLLBACK", NULL, NULL, NULL);
            }
            break;
        }else if(isSelectQuery && aTarget!=nil && aSelector!=nil){
            NSDictionary *row=nil;
            while ((row=[self getNextRowAsDictionary])) {
                [aTarget performSelector:aSelector withObject:[NSNumber numberWithInt:i] withObject:row];
            }
        }
    }
    
    return status;
}


//This method returns the row from the result set of recently executed SELECT statement as an array.
- (NSArray *) getNextRowAsArray{
    NSMutableArray *row=nil;
    
    if(sqlite3_step(statement)==SQLITE_ROW){
        //NSLog(@"[VZSQLiteManager] getNextRowAsArray");
        row=[NSMutableArray arrayWithCapacity:currentColumnCount];
        for(int i=0;i<currentColumnCount;i++){
            int dataType=sqlite3_column_type(statement, i);
            if(dataType==SQLITE_INTEGER){
                [row addObject:[NSNumber numberWithInt:sqlite3_column_int(statement, i)]];
            }else if(dataType==SQLITE_FLOAT){
                [row addObject:[NSNumber numberWithDouble:sqlite3_column_double(statement, i)]];
            }else if(dataType==SQLITE_TEXT){
                [row addObject:[NSString stringWithUTF8String:(const char*)sqlite3_column_text(statement, i)]];
            }else if(dataType==SQLITE_BLOB){
                NSData *blobData=[NSData dataWithBytes:sqlite3_column_blob(statement,i) length:sqlite3_column_bytes(statement,i)];
                [row addObject:blobData];
            }else if(dataType==SQLITE_NULL){
                [row addObject:[NSNull null]];//or add "" string instead of null.
            }
        }
        
    }else{
        //Whatever might be the reason,SQLITE_DONE or SQLITE_ERROR(or it's variant) do release the memory for the prepared statement.
        [self clearState];
    }
    
    return row;
}



//This method returns the row from the result set of recently executed SELECT statement as a dictionary.
//The returned dictionary can be looked up for the column names & corresponding values can be retrieved.
- (NSDictionary *) getNextRowAsDictionary{
    NSMutableDictionary *row=nil;
    
    if(sqlite3_step(statement)==SQLITE_ROW){
        row=[NSMutableDictionary dictionaryWithCapacity:currentColumnCount];
        for(int i=0;i<currentColumnCount;i++){
            int dataType=sqlite3_column_type(statement, i);
            if(dataType==SQLITE_INTEGER){
                [row setObject:[NSNumber numberWithInt:sqlite3_column_int(statement, i)] forKey:[NSString stringWithUTF8String:sqlite3_column_name(statement, i)]];
            }else if(dataType==SQLITE_FLOAT){
                [row setObject:[NSNumber numberWithDouble:sqlite3_column_double(statement, i)] forKey:[NSString stringWithUTF8String:sqlite3_column_name(statement, i)]];
            }else if(dataType==SQLITE_TEXT){
                [row setObject:[NSString stringWithUTF8String:(const char*)sqlite3_column_text(statement, i)] forKey:[NSString stringWithUTF8String:sqlite3_column_name(statement, i)]];
            }else if(dataType==SQLITE_BLOB){
                [row setObject:[NSData dataWithBytes:sqlite3_column_blob(statement,i) length:sqlite3_column_bytes(statement,i)] forKey:[NSString stringWithUTF8String:sqlite3_column_name(statement, i)]];
            }else if(dataType==SQLITE_NULL){
                [row setObject:[NSNull null] forKey:[NSString stringWithUTF8String:sqlite3_column_name(statement, i)]];
            }
        }
    }else{
        //Whatever might be the reason,SQLITE_DONE or SQLITE_ERROR(or it's variant) do release the memory for the prepared statement.
        [self clearState];
    }
    
    return row;
}



- (NSArray *) getResultSetForQuery:(NSString *) query withParams:(NSArray *) params{
    BOOL status = [self executeQuery:query withParams:params];
    NSMutableArray *resultSet = nil;
    
    if (status) {
        resultSet = [NSMutableArray array];
        NSArray *row;
        while ((row = [self getNextRowAsArray]) !=nil) {
            [resultSet addObject:row];
        }
    }
    
    return resultSet;
}

@end
