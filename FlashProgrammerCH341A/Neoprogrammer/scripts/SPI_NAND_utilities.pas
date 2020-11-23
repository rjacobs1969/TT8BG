// designed for SPI NAND
// Read first (full) page of a given block
// Read given (full) page
// Read BBM Look Up Table (winbond)
{$ READ_JEDEC_ID}
begin
  ID:= CreateByteArray(2);
  if not SPIEnterProgMode(_SPI_SPEED_MAX) then LogPrint('Error setting SPI speed');
  LogPrint ('Read JEDEC ID');
  
  // read ID to test installation 
  SPIWrite (0, 2, $9F, $00);
  SPIRead(1, 2, ID);
  
  logprint('CHIP ID: ' + inttohex((GetArrayItem(ID, 0)),2)+ inttohex((GetArrayItem(ID, 1)),2));
  LogPrint ('End read JEDEC ID');
  SPIExitProgMode ();
end

{$ READ_first_PAGE_of_a_BLOCK}
begin
  if not SPIEnterProgMode(_SPI_SPEED_MAX) then LogPrint('Error setting SPI speed');
  LogPrint ('Read first (full) page of a given block');
  sreg :=$FF;
  buff:= CreateByteArray(4);
  PageSize :=2048;
  SpareSize:=128; // or 64
  bufflen:= PageSize + SpareSize;
  repeat
   BlockNum := InputBox('Enter Block Number (0 to 1023)','','0');
  until (BlockNum >=0) and (BlockNum <=1023);

  Address:= BlockNum * 64 * PageSize;

  Addr:= Address shr 11; // same as Address div 2048
  SetArrayItem(buff, 0, $13);
  SetArrayItem(buff, 1, (addr shr 16)); // div 65536
  SetArrayItem(buff, 2, (addr shr 8));  // div 256
  SetArrayItem(buff, 3, (addr));
  // transfer page datas to cache
  SPIWrite (1, 4, buff);
  
  // wait if busy
    repeat
      SPIWrite(0, 2, $0F, $C0);
      SPIRead(1, 1, sreg);
    until((sreg and 1) <> 1);

  SetArrayItem(buff, 0, $03);
  SetArrayItem(buff, 1, 0);
  SetArrayItem(buff, 2, 0); // read cache from 0, bufflen length 
  SetArrayItem(buff, 3, 0); // dummy byte
  SPIWrite (0, 4, buff);
  
  SPIReadToEditor (1, bufflen);

  LogPrint ('End read page');
  SPIExitProgMode ();
end

{$ READ_PAGE}
begin
  if not SPIEnterProgMode(_SPI_SPEED_MAX) then LogPrint('Error setting SPI speed');
  LogPrint ('Read (full) given page');
  sreg :=$FF;
  buff:= CreateByteArray(4);
  PageSize :=2048;
  SpareSize:=128; // or 64
  bufflen:= PageSize + SpareSize;
  repeat
   PageNum := InputBox('Enter page Number (0 to 65535)','','0');
  until (PageNum >=0) and (PageNum <=65535);

  Address:= PageNum * PageSize;

  Addr:= Address shr 11; // same as Address div 2048
  SetArrayItem(buff, 0, $13);
  SetArrayItem(buff, 1, (addr shr 16)); // div 65536
  SetArrayItem(buff, 2, (addr shr 8));  // div 256
  SetArrayItem(buff, 3, (addr));
  // transfer page datas to cache
  SPIWrite (1, 4, buff);
  
  // wait if busy
    repeat
      SPIWrite(0, 2, $0F, $C0);
      SPIRead(1, 1, sreg);
    until((sreg and 1) <> 1);

  SetArrayItem(buff, 0, $03);
  SetArrayItem(buff, 1, 0);
  SetArrayItem(buff, 2, 0); // read cache from 0, bufflen length 
  SetArrayItem(buff, 3, 0); // dummy byte
  SPIWrite (0, 4, buff);
  
  SPIReadToEditor (1, bufflen);

  LogPrint ('End read page');
  SPIExitProgMode ();
end

{$ READ_BBM_table}
begin
  BBM:= CreateByteArray(40);
  if not SPIEnterProgMode(_SPI_SPEED_MAX) then LogPrint('Error setting SPI speed');
  LogPrint ('Read BBM table');
  
  // read winbond BBM table 
  SPIWrite (0, 2, $A5, $00);
  SPIRead(1, 40, BBM);
  // only 5 couple of data (to be completed)
  logprint('LBA0: ' + inttohex((GetArrayItem(BBM, 0)),2)  + inttohex((GetArrayItem(BBM, 1)),2)  + ' PBA0: ' + inttohex((GetArrayItem(BBM, 2)),2) + inttohex((GetArrayItem(BBM, 3)),2));
  logprint('LBA1: ' + inttohex((GetArrayItem(BBM, 4)),2)  + inttohex((GetArrayItem(BBM, 5)),2)  + ' PBA1: ' + inttohex((GetArrayItem(BBM, 6)),2) + inttohex((GetArrayItem(BBM, 7)),2));
  logprint('LBA2: ' + inttohex((GetArrayItem(BBM, 8)),2)  + inttohex((GetArrayItem(BBM, 9)),2)  + ' PBA2: ' + inttohex((GetArrayItem(BBM, 10)),2)+ inttohex((GetArrayItem(BBM, 11)),2));
  logprint('LBA3: ' + inttohex((GetArrayItem(BBM, 12)),2) + inttohex((GetArrayItem(BBM, 13)),2) + ' PBA3: ' + inttohex((GetArrayItem(BBM, 14)),2)+ inttohex((GetArrayItem(BBM, 15)),2));
  logprint('LBA4: ' + inttohex((GetArrayItem(BBM, 16)),2) + inttohex((GetArrayItem(BBM, 17)),2) + ' PBA4: ' + inttohex((GetArrayItem(BBM, 18)),2)+ inttohex((GetArrayItem(BBM, 19)),2));
  logprint('LBA5: ' + inttohex((GetArrayItem(BBM, 20)),2) + inttohex((GetArrayItem(BBM, 21)),2) + ' PBA5: ' + inttohex((GetArrayItem(BBM, 22)),2)+ inttohex((GetArrayItem(BBM, 23)),2));
  LogPrint ('End read BBM table');
  SPIExitProgMode ();
end