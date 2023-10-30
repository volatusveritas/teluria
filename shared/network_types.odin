package shared

StringLengthType :: u32le

NetworkMessageType :: enum u32le
{
    LOGIN,
    REGISTER,
    MESSAGE,
}
